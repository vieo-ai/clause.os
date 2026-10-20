# clause.ps1 - Cross-Platform Stage 0 Microkernel & Confined Profile Bootloader
$ErrorActionPreference = 'Stop'

$ProjectRoot = if ($env:CLAUSE_PROJECT_ROOT) { $env:CLAUSE_PROJECT_ROOT } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# ==============================================================================
# PRE-BOOT ENVIRONMENT LOCKING & ATTRIBUTE CLEANUP
# ==============================================================================
# Override Windows AppData variables early (Windows only)
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    $env:APPDATA      = Join-Path $ProjectRoot ".local\appdata"
    $env:LOCALAPPDATA = Join-Path $ProjectRoot ".local\share"
}

$EnvScript = Join-Path $ProjectRoot ".config\pwsh\env.ps1"
if (Test-Path $EnvScript) {
    . $EnvScript
}

$LocalBin    = Join-Path $ProjectRoot ".local\bin"
$AppDir      = Join-Path $ProjectRoot ".local\app"
$CacheDir    = Join-Path $ProjectRoot ".cache"
$TmpDir      = Join-Path $CacheDir "tmp_bootstrap"
$Manifest    = Join-Path $ProjectRoot ".clause.toml"
$NuConfigDir = Join-Path $ProjectRoot ".config\nushell"

# Target Application Directories
$InferenceGpuDir = Join-Path $AppDir "lemonade"
$InferenceNpuDir = Join-Path $AppDir "fastflowlm"
$ApmDir          = Join-Path $AppDir "apm"
$CodeDir         = Join-Path $AppDir "vscode"

if (-not (Test-Path $Manifest)) {
    throw "[ClauseOS] Error: Manifest file not found at $Manifest"
}

function Get-TomlValue([string]$Content, [string]$Key) {
    $Pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*"([^"]+)"'
    $Match = [regex]::Match($Content, $Pattern)
    if ($Match.Success) { return $Match.Groups[1].Value }
    return $null
}

function Get-File([string]$Url, [string]$OutFile) {
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        curl.exe -sSL "$Url" -o "$OutFile"
        if ($LASTEXITCODE -ne 0) { throw "[ClauseOS] Download failed via curl.exe for URL: $Url" }
    } elseif (Get-Command curl -ErrorAction SilentlyContinue) {
        curl -sSL "$Url" -o "$OutFile"
        if ($LASTEXITCODE -ne 0) { throw "[ClauseOS] Download failed via curl for URL: $Url" }
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    }
}

function Expand-HermeticArchive([string]$ArchivePath, [string]$DestinationPath) {
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    }
    if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
        tar.exe -xf "$ArchivePath" -C "$DestinationPath"
        if ($LASTEXITCODE -ne 0) { throw "[ClauseOS] Archive extraction failed via tar.exe for: $ArchivePath" }
    } elseif (Get-Command tar -ErrorAction SilentlyContinue) {
        tar -xf "$ArchivePath" -C "$DestinationPath"
        if ($LASTEXITCODE -ne 0) { throw "[ClauseOS] Archive extraction failed via tar for: $ArchivePath" }
    } else {
        Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
    }
}

function Install-ExtractedArchive([string]$ExtractTarget, [string]$DestinationPath) {
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    }
    $ChildItems = Get-ChildItem -Path $ExtractTarget
    if ($ChildItems.Count -eq 1 -and $ChildItems[0].PSIsContainer) {
        Get-ChildItem -Path $ChildItems[0].FullName | Move-Item -Destination $DestinationPath -Force
    } else {
        Get-ChildItem -Path $ExtractTarget | Move-Item -Destination $DestinationPath -Force
    }
}

function Set-PosixExecutable([string]$FilePath) {
    if (-not ($IsWindows -or $env:OS -eq "Windows_NT")) {
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            chmod +x "$FilePath" 2>$null
        }
    }
}

$TomlContent = Get-Content -Path $Manifest -Raw

# Manifest Versions
$MiseVer     = Get-TomlValue -Content $TomlContent -Key "mise"
$JustVer     = Get-TomlValue -Content $TomlContent -Key "just"
$NuVer       = Get-TomlValue -Content $TomlContent -Key "nu"
$LemonadeVer = Get-TomlValue -Content $TomlContent -Key "lemonade"
$FastFlowVer = Get-TomlValue -Content $TomlContent -Key "fastflowlm"
$ApmVer      = Get-TomlValue -Content $TomlContent -Key "apm"
$VsCodeVer   = Get-TomlValue -Content $TomlContent -Key "vscode"

if (-not $MiseVer -or -not $JustVer -or -not $NuVer -or -not $LemonadeVer -or -not $FastFlowVer -or -not $ApmVer -or -not $VsCodeVer) {
    throw "[ClauseOS] Error: Missing required version definitions in .clause.toml"
}

# Version Sanitizers
$LemonadeTag   = if ($LemonadeVer.StartsWith("v")) { $LemonadeVer } else { "v$LemonadeVer" }
$LemonadeClean = $LemonadeTag.TrimStart("v")
$FastFlowTag   = if ($FastFlowVer.StartsWith("v")) { $FastFlowVer } else { "v$FastFlowVer" }
$FastFlowClean = $FastFlowTag.TrimStart("v")
$ApmTag        = if ($ApmVer.StartsWith("v")) { $ApmVer } else { "v$ApmVer" }

# Provision Directories
@($LocalBin, $AppDir, $TmpDir, $InferenceGpuDir, $InferenceNpuDir, $ApmDir, $CodeDir, $NuConfigDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
}

# Target Executable Names
$ExeExt = if ($IsWindows -or $env:OS -eq "Windows_NT") { ".exe" } else { "" }

# ==============================================================================
# STAGE 0: CORE SYSTEM ENGINE SEEDING
# ==============================================================================

# 1. Mise Engine -> .local/bin/
$MiseBin = Join-Path $LocalBin "mise$ExeExt"
if (-not (Test-Path $MiseBin)) {
    Write-Host "[ClauseOS Stage 0] Pre-seeding Mise (v${MiseVer}) into .local/bin/..." -ForegroundColor Cyan
    $MiseAsset = if ($IsWindows) { "mise-v${MiseVer}-windows-x64.zip" } elseif ($IsMacOS) { "mise-v${MiseVer}-macos-x64.tar.gz" } else { "mise-v${MiseVer}-linux-x64.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $MiseAsset
    Get-File -Url "https://github.com/jdx/mise/releases/download/v${MiseVer}/$MiseAsset" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "mise_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    $FoundMise = Get-ChildItem -Path $ExtractTarget -Filter "mise$ExeExt" -Recurse | Select-Object -First 1
    if ($FoundMise) {
        Get-ChildItem -Path $FoundMise.DirectoryName | Move-Item -Destination $LocalBin -Force
        Set-PosixExecutable -FilePath $MiseBin
    }
}

# 2. Just Task Scheduler -> .local/bin/
$JustBin = Join-Path $LocalBin "just$ExeExt"
if (-not (Test-Path $JustBin)) {
    Write-Host "[ClauseOS Stage 0] Pre-seeding Just (v${JustVer}) into .local/bin/..." -ForegroundColor Cyan
    $JustAsset = if ($IsWindows) { "just-${JustVer}-x86_64-pc-windows-msvc.zip" } elseif ($IsMacOS) { "just-${JustVer}-x86_64-apple-darwin.tar.gz" } else { "just-${JustVer}-x86_64-unknown-linux-musl.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $JustAsset
    Get-File -Url "https://github.com/casey/just/releases/download/${JustVer}/$JustAsset" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "just_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    $FoundJust = Get-ChildItem -Path $ExtractTarget -Filter "just$ExeExt" -Recurse | Select-Object -First 1
    if ($FoundJust) {
        Move-Item -Path $FoundJust.FullName -Destination $LocalBin -Force
        Set-PosixExecutable -FilePath $JustBin
    }
}

# 3. Nushell Shell Engine -> .local/bin/
$NuBin = Join-Path $LocalBin "nu$ExeExt"
if (-not (Test-Path $NuBin)) {
    Write-Host "[ClauseOS Stage 0] Pre-seeding Nushell (v${NuVer}) into .local/bin/..." -ForegroundColor Cyan
    $NuAsset = if ($IsWindows) { "nu-${NuVer}-x86_64-pc-windows-msvc.zip" } elseif ($IsMacOS) { "nu-${NuVer}-x86_64-apple-darwin.tar.gz" } else { "nu-${NuVer}-x86_64-unknown-linux-gnu.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $NuAsset
    Get-File -Url "https://github.com/nushell/nushell/releases/download/${NuVer}/$NuAsset" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "nu_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    $FoundNu = Get-ChildItem -Path $ExtractTarget -Filter "nu$ExeExt" -Recurse | Select-Object -First 1
    if ($FoundNu) {
        Get-ChildItem -Path $FoundNu.DirectoryName | Move-Item -Destination $LocalBin -Force
        Set-PosixExecutable -FilePath $NuBin
    }
}

# ==============================================================================
# STAGE 1: PORTABLE APPS & AI COMPONENT SEEDING
# ==============================================================================

# 4. Lemonade GPU Engine -> .local/app/lemonade/
$LemonadeCheck = Get-ChildItem -Path $InferenceGpuDir -ErrorAction SilentlyContinue
if (-not $LemonadeCheck) {
    Write-Host "[ClauseOS Stage 1] Seeding Lemonade GPU Engine (${LemonadeTag})..." -ForegroundColor Cyan
    $LemonadeAsset = if ($IsWindows) { "lemonade-embeddable-${LemonadeClean}-windows-x64.zip" } elseif ($IsMacOS) { "lemonade-embeddable-${LemonadeClean}-macos-arm64.tar.gz" } else { "lemonade-embeddable-${LemonadeClean}-ubuntu-x64.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $LemonadeAsset
    Get-File -Url "https://github.com/lemonade-sdk/lemonade/releases/download/${LemonadeTag}/${LemonadeAsset}" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "lemonade_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $InferenceGpuDir
}

# 5. FastFlowLM NPU Engine -> .local/app/fastflowlm/ (Linux & Windows)
if (-not $IsMacOS) {
    $FastFlowCheck = Get-ChildItem -Path $InferenceNpuDir -ErrorAction SilentlyContinue
    if (-not $FastFlowCheck) {
        Write-Host "[ClauseOS Stage 1] Seeding FastFlowLM NPU Engine (${FastFlowTag})..." -ForegroundColor Cyan
        $FastFlowAsset = if ($IsWindows) { "fastflowlm_${FastFlowClean}_windows_amd64.zip" } else { "fastflowlm_${FastFlowClean}_linux.tar.gz" }
        $ArchivePath = Join-Path $TmpDir $FastFlowAsset
        Get-File -Url "https://github.com/ROCm/FastFlowLM/releases/download/${FastFlowTag}/${FastFlowAsset}" -OutFile $ArchivePath
        
        $ExtractTarget = Join-Path $TmpDir "fastflow_out"
        Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
        Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $InferenceNpuDir
    }
}

# 6. APM (Agent Package Manager) -> .local/app/apm/
$ApmBin = Join-Path $ApmDir "apm$ExeExt"
if (-not (Test-Path $ApmBin)) {
    Write-Host "[ClauseOS Stage 1] Seeding Agent Package Manager (${ApmTag})..." -ForegroundColor Cyan
    $ApmAsset = if ($IsWindows) { "apm-windows-x86_64.zip" } elseif ($IsMacOS) { "apm-darwin-x86_64.tar.gz" } else { "apm-linux-x86_64.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $ApmAsset
    Get-File -Url "https://github.com/microsoft/apm/releases/download/${ApmTag}/${ApmAsset}" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "apm_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $ApmDir
    Set-PosixExecutable -FilePath $ApmBin
}

# 7. VS Code Portable -> .local/app/vscode/
$CodeCheck = Get-ChildItem -Path $CodeDir -ErrorAction SilentlyContinue
if (-not $CodeCheck) {
    Write-Host "[ClauseOS Stage 1] Seeding VS Code Portable Engine (v${VsCodeVer})..." -ForegroundColor Cyan
    $CodeAsset = if ($IsWindows) { "vscode-win32-x64-${VsCodeVer}.zip" } elseif ($IsMacOS) { "VSCode-darwin-universal.zip" } else { "vscode-linux-x64-${VsCodeVer}.tar.gz" }
    $CodeUrl = if ($IsWindows) { "https://update.code.visualstudio.com/${VsCodeVer}/win32-x64-archive/stable" } elseif ($IsMacOS) { "https://update.code.visualstudio.com/${VsCodeVer}/darwin-universal/stable" } else { "https://update.code.visualstudio.com/${VsCodeVer}/linux-x64/stable" }
    
    $ArchivePath = Join-Path $TmpDir $CodeAsset
    Get-File -Url $CodeUrl -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "code_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $CodeDir
    New-Item -ItemType Directory -Path (Join-Path $CodeDir "data") -Force | Out-Null
}

# Cleanup transient downloads
if (Test-Path $TmpDir) { Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------------------
# WINDOWS PROFILE CLEANUP (GRACEFULLY SKIPPED ON POSIX)
# ---------------------------------------------------------------------------
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    if (Get-Command attrib.exe -ErrorAction SilentlyContinue) {
        $ProfileTargets = @("AppData", "Microsoft")
        foreach ($Target in $ProfileTargets) {
            $FullPath = Join-Path $ProjectRoot $Target
            if (Test-Path $FullPath) { attrib.exe +h "$FullPath" 2>$null }
        }

        Get-ChildItem -Path $ProjectRoot -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name.StartsWith(".") } | ForEach-Object {
            attrib.exe +h "$($_.FullName)" 2>$null
        }
    }
}

# ==============================================================================
# GENERATE NUSHELL MISE ACTIVATION OVERLAY (NATIVE NUSHELL EXECUTION)
# ==============================================================================
$MiseBin = Join-Path $LocalBin "mise$ExeExt"
$NuBin   = Join-Path $LocalBin "nu$ExeExt"
$MiseNu  = Join-Path $NuConfigDir "mise.nu"

if ((Test-Path $MiseBin) -and (Test-Path $NuBin)) {
    Write-Host "[ClauseOS Stage 0] Syncing Mise Nushell overlay..." -ForegroundColor Cyan
    & $NuBin -c "mise activate nu | save '$MiseNu' --force"
}

# ==============================================================================
# STAGE 2: NUSHELL HANDOFF (CLI, CI/CD NON-INTERACTIVE, & TTY ROUTING)
# ==============================================================================
$EnvNu    = Join-Path $ProjectRoot "scripts/cli/nu/core/boot.nu"
$ConfigNu = Join-Path $NuConfigDir "config.nu"
$IsNonInteractive = [Console]::IsInputRedirected -or $env:CI -eq "true"

if (Test-Path $NuBin) {
    if (Test-Path $EnvNu) {
        if ($args.Count -gt 0) {
            $CommandString = $args -join " "
            & $NuBin --env-config $EnvNu -c "clause $CommandString"
            exit $LASTEXITCODE
        } elseif ($IsNonInteractive) {
            & $NuBin --env-config $EnvNu -c "clause boot:check"
            exit $LASTEXITCODE
        } else {
            if (Test-Path $ConfigNu) {
                & $NuBin --env-config $EnvNu --config $ConfigNu -e "clause banner"
            } else {
                & $NuBin --env-config $EnvNu -e "clause banner"
            }
        }
    } else {
        Write-Host "  WARN  Environment file not found at $EnvNu. Booting default Nushell shell..." -ForegroundColor Yellow
        & $NuBin
    }
} else {
    Write-Host "  FAIL  Nushell ($NuBin) could not be located in .local/bin." -ForegroundColor Red
    exit 1
}