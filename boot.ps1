# clause.ps1 - Cross-Platform Stage 0 Microkernel & Confined Profile Bootloader
$ErrorActionPreference = 'Stop'

$ProjectRoot = if ($env:CLAUSE_PROJECT_ROOT) { $env:CLAUSE_PROJECT_ROOT } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# ==============================================================================
# OS & PLATFORM DETECTION
# ==============================================================================
$IsOSWindows = $IsWindows -or $env:OS -eq "Windows_NT"
$IsOSMac     = $IsMacOS -or ($PSVersionTable.OS -like "*Darwin*")
$IsOSLinux   = -not $IsOSWindows -and -not $IsOSMac

# ==============================================================================
# LOGGING SYSTEM INITIALIZATION
# ==============================================================================
$LogDir  = Join-Path $ProjectRoot ".local\logs"
$LogFile = Join-Path $LogDir "bootstrap.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

function Write-ClauseLog {
    param (
        [Parameter(Mandatory=$true)] [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")] [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry  = "[$Timestamp] [$Level] $Message"

    try {
        Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
    } catch {
        # Fallback if log file is temporarily locked
    }

    switch ($Level) {
        "INFO"  { Write-Host "[ClauseOS] $Message" -ForegroundColor Cyan }
        "WARN"  { Write-Host "[ClauseOS WARN] $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[ClauseOS ERROR] $Message" -ForegroundColor Red }
        "FATAL" { Write-Host "[ClauseOS FATAL] $Message" -ForegroundColor DarkRed }
        "DEBUG" { Write-Host "[ClauseOS DEBUG] $Message" -ForegroundColor DarkGray }
    }
}

Write-ClauseLog "Initializing ClauseOS Microkernel Bootloader..." -Level INFO
Write-ClauseLog "Context: Root=$ProjectRoot | OS(Windows=$IsOSWindows, Linux=$IsOSLinux, Mac=$IsOSMac)" -Level DEBUG

# ==============================================================================
# PRE-BOOT ENVIRONMENT LOCKING & ATTRIBUTE CLEANUP
# ==============================================================================
if ($IsOSWindows) {
    $env:APPDATA      = Join-Path $ProjectRoot ".local\appdata"
    $env:LOCALAPPDATA = Join-Path $ProjectRoot ".local\share"
    Write-ClauseLog "Applied Windows AppData profile overrides" -Level DEBUG
}

$EnvScript = Join-Path $ProjectRoot ".config\pwsh\env.ps1"
if (Test-Path $EnvScript) {
    try {
        . $EnvScript
        Write-ClauseLog "Loaded PowerShell environment script: $EnvScript" -Level DEBUG
    } catch {
        Write-ClauseLog "Failed to execute environment script '$EnvScript': $_" -Level WARN
    }
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
    Write-ClauseLog "Manifest file missing at path: $Manifest" -Level FATAL
    throw "[ClauseOS] Error: Manifest file not found at $Manifest"
}

function Get-TomlValue([string]$Content, [string]$Key) {
    $Pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*"([^"]+)"'
    $Match = [regex]::Match($Content, $Pattern)
    if ($Match.Success) { return $Match.Groups[1].Value }
    return $null
}

function Get-File([string]$Url, [string]$OutFile) {
    Write-ClauseLog "Downloading asset: $Url -> $OutFile" -Level DEBUG
    try {
        if ($IsOSWindows) {
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                curl.exe -sSL "$Url" -o "$OutFile"
                if ($LASTEXITCODE -ne 0) { throw "curl.exe exited with code $LASTEXITCODE" }
            } else {
                Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
            }
        } else {
            if (Get-Command curl -ErrorAction SilentlyContinue) {
                curl -sSL "$Url" -o "$OutFile"
                if ($LASTEXITCODE -ne 0) { throw "curl exited with code $LASTEXITCODE" }
            } else {
                Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
            }
        }
    } catch {
        Write-ClauseLog "Download failed for URL '$Url': $_" -Level ERROR
        throw "[ClauseOS] Download failed via curl for URL: $Url"
    }
}

function Expand-HermeticArchive([string]$ArchivePath, [string]$DestinationPath) {
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    }

    Write-ClauseLog "Extracting archive: $ArchivePath -> $DestinationPath" -Level DEBUG
    try {
        if ($IsOSWindows) {
            if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
                tar.exe -xf "$ArchivePath" -C "$DestinationPath"
                if ($LASTEXITCODE -ne 0) { throw "tar.exe failed with code $LASTEXITCODE" }
            } else {
                Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
            }
        } else {
            # POSIX (Linux / macOS / WSL2): Force native Linux/macOS tar to prevent Windows tar.exe leak
            $NativeTar = if (Test-Path "/usr/bin/tar") { "/usr/bin/tar" } elseif (Test-Path "/bin/tar") { "/bin/tar" } else { "tar" }
            & $NativeTar -xf "$ArchivePath" -C "$DestinationPath"
            if ($LASTEXITCODE -ne 0) { throw "$NativeTar failed with code $LASTEXITCODE" }
        }
    } catch {
        Write-ClauseLog "Archive extraction failed for '$ArchivePath': $_" -Level ERROR
        throw $_
    }
}

function Install-ExtractedArchive([string]$ExtractTarget, [string]$DestinationPath) {
    # Guard: Ensure ExtractTarget is explicitly within $TmpDir to protect project root
    if (-not $ExtractTarget.StartsWith($TmpDir)) {
        Write-ClauseLog "Extraction target $ExtractTarget is outside $TmpDir" -Level FATAL
        throw "[ClauseOS] Critical Error: Extraction target $ExtractTarget is outside $TmpDir"
    }

    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    }

    $ChildItems = Get-ChildItem -Path $ExtractTarget -Force -ErrorAction Stop
    if ($ChildItems.Count -eq 0) {
        Write-ClauseLog "Extraction target directory is empty: $ExtractTarget" -Level ERROR
        throw "[ClauseOS] Error: Extract target is empty: $ExtractTarget"
    }

    try {
        if ($ChildItems.Count -eq 1 -and $ChildItems[0].PSIsContainer) {
            Write-ClauseLog "Moving single container content '$($ChildItems[0].Name)' to $DestinationPath" -Level DEBUG
            Get-ChildItem -Path $ChildItems[0].FullName -Force | Move-Item -Destination $DestinationPath -Force
        } else {
            Write-ClauseLog "Moving extracted directory contents to $DestinationPath" -Level DEBUG
            Get-ChildItem -Path $ExtractTarget -Force | Move-Item -Destination $DestinationPath -Force
        }
    } catch {
        Write-ClauseLog "Failed to move extracted archive to '$DestinationPath': $_" -Level ERROR
        throw $_
    }
}

function Set-PosixExecutable([string]$FilePath) {
    if (-not $IsOSWindows) {
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            chmod +x "$FilePath" 2>$null
            Write-ClauseLog "Applied chmod +x to $FilePath" -Level DEBUG
        }
    }
}

try {
    $TomlContent = Get-Content -Path $Manifest -Raw
} catch {
    Write-ClauseLog "Unable to read manifest file: $_" -Level FATAL
    throw $_
}

# Manifest Versions
$MiseVer     = Get-TomlValue -Content $TomlContent -Key "mise"
$JustVer     = Get-TomlValue -Content $TomlContent -Key "just"
$NuVer       = Get-TomlValue -Content $TomlContent -Key "nu"
$LemonadeVer = Get-TomlValue -Content $TomlContent -Key "lemonade"
$FastFlowVer = Get-TomlValue -Content $TomlContent -Key "fastflowlm"
$ApmVer      = Get-TomlValue -Content $TomlContent -Key "apm"
$VsCodeVer   = Get-TomlValue -Content $TomlContent -Key "vscode"

if (-not $MiseVer -or -not $JustVer -or -not $NuVer -or -not $LemonadeVer -or -not $FastFlowVer -or -not $ApmVer -or -not $VsCodeVer) {
    Write-ClauseLog "Incomplete version metadata in .clause.toml" -Level FATAL
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
$ExeExt = if ($IsOSWindows) { ".exe" } else { "" }

# ==============================================================================
# STAGE 0: CORE SYSTEM ENGINE SEEDING
# ==============================================================================

# 1. Mise Engine -> .local/bin/ (with POSIX man/share routing)
$MiseBin = Join-Path $LocalBin "mise$ExeExt"
if (-not (Test-Path $MiseBin)) {
    Write-ClauseLog "Pre-seeding Mise (v${MiseVer}) into .local/bin/..." -Level INFO
    $MiseAsset = if ($IsOSWindows) { "mise-v${MiseVer}-windows-x64.zip" } elseif ($IsOSMac) { "mise-v${MiseVer}-macos-x64.tar.gz" } else { "mise-v${MiseVer}-linux-x64.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $MiseAsset
    Get-File -Url "https://github.com/jdx/mise/releases/download/v${MiseVer}/$MiseAsset" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "mise_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget

    # Locate the executable file strictly within the extraction output
    $FoundMiseExe = Get-ChildItem -Path $ExtractTarget -Filter "mise$ExeExt" -Recurse | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1

    if ($FoundMiseExe) {
        # Move all files in the bin folder (mise, mise-shim.exe, mise-shims, etc.) directly to .local/bin/
        Get-ChildItem -Path $FoundMiseExe.DirectoryName | Move-Item -Destination $LocalBin -Force
        Set-PosixExecutable -FilePath $MiseBin

        # POSIX (Linux/macOS): Route sibling folders (man, share) into .local/man/ and .local/share/
        if (-not $IsOSWindows) {
            $MiseParent = $FoundMiseExe.Directory.Parent
            if ($MiseParent -and (Test-Path $MiseParent.FullName) -and ($MiseParent.FullName -ne $ExtractTarget)) {
                Get-ChildItem -Path $MiseParent.FullName | Where-Object { $_.Name -ne "bin" } | ForEach-Object {
                    $DestDir = Join-Path $ProjectRoot ".local/$($_.Name)"
                    if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Force -Path $DestDir | Out-Null }
                    Get-ChildItem -Path $_.FullName | Move-Item -Destination $DestDir -Force
                }
            }
        }
    } else {
        Write-ClauseLog "Mise executable ($MiseBin) could not be located in extracted archive" -Level ERROR
        throw "[ClauseOS ERROR] Mise binary missing in $ExtractTarget"
    }
}

# 2. Just Task Scheduler -> .local/bin/
$JustBin = Join-Path $LocalBin "just$ExeExt"
if (-not (Test-Path $JustBin)) {
    Write-ClauseLog "Pre-seeding Just (v${JustVer}) into .local/bin/..." -Level INFO
    $JustAsset = if ($IsOSWindows) { "just-${JustVer}-x86_64-pc-windows-msvc.zip" } elseif ($IsOSMac) { "just-${JustVer}-x86_64-apple-darwin.tar.gz" } else { "just-${JustVer}-x86_64-unknown-linux-musl.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $JustAsset
    Get-File -Url "https://github.com/casey/just/releases/download/${JustVer}/$JustAsset" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "just_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $LocalBin
    Set-PosixExecutable -FilePath $JustBin
}

# 3. Nushell Shell Engine -> .local/bin/
$NuBin = Join-Path $LocalBin "nu$ExeExt"
if (-not (Test-Path $NuBin)) {
    Write-ClauseLog "Pre-seeding Nushell (v${NuVer}) into .local/bin/..." -Level INFO
    $NuAsset = if ($IsOSWindows) { "nu-${NuVer}-x86_64-pc-windows-msvc.zip" } elseif ($IsOSMac) { "nu-${NuVer}-x86_64-apple-darwin.tar.gz" } else { "nu-${NuVer}-x86_64-unknown-linux-gnu.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $NuAsset
    Get-File -Url "https://github.com/nushell/nushell/releases/download/${NuVer}/$NuAsset" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "nu_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $LocalBin
    Set-PosixExecutable -FilePath $NuBin
}

# ==============================================================================
# STAGE 1: PORTABLE APPS & AI COMPONENT SEEDING
# ==============================================================================

# 4. Lemonade GPU Engine -> .local/app/lemonade/
$LemonadeCheck = Get-ChildItem -Path $InferenceGpuDir -ErrorAction SilentlyContinue
if (-not $LemonadeCheck) {
    Write-ClauseLog "Seeding Lemonade GPU Engine (${LemonadeTag})..." -Level INFO
    $LemonadeAsset = if ($IsOSWindows) { "lemonade-embeddable-${LemonadeClean}-windows-x64.zip" } elseif ($IsOSMac) { "lemonade-embeddable-${LemonadeClean}-macos-arm64.tar.gz" } else { "lemonade-embeddable-${LemonadeClean}-ubuntu-x64.tar.gz" }
    $ArchivePath = Join-Path $TmpDir $LemonadeAsset
    Get-File -Url "https://github.com/lemonade-sdk/lemonade/releases/download/${LemonadeTag}/${LemonadeAsset}" -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "lemonade_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $InferenceGpuDir
}

# 5. FastFlowLM NPU Engine -> .local/app/fastflowlm/ (Linux & Windows)
if (-not $IsOSMac) {
    $FastFlowCheck = Get-ChildItem -Path $InferenceNpuDir -ErrorAction SilentlyContinue
    if (-not $FastFlowCheck) {
        Write-ClauseLog "Seeding FastFlowLM NPU Engine (${FastFlowTag})..." -Level INFO
        $FastFlowAsset = if ($IsOSWindows) { "fastflowlm_${FastFlowClean}_windows_amd64.zip" } else { "fastflowlm_${FastFlowClean}_linux.tar.gz" }
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
    Write-ClauseLog "Seeding Agent Package Manager (${ApmTag})..." -Level INFO
    $ApmAsset = if ($IsOSWindows) { "apm-windows-x86_64.zip" } elseif ($IsOSMac) { "apm-darwin-x86_64.tar.gz" } else { "apm-linux-x86_64.tar.gz" }
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
    Write-ClauseLog "Seeding VS Code Portable Engine (v${VsCodeVer})..." -Level INFO
    $CodeAsset = if ($IsOSWindows) { "vscode-win32-x64-${VsCodeVer}.zip" } elseif ($IsOSMac) { "VSCode-darwin-universal.zip" } else { "vscode-linux-x64-${VsCodeVer}.tar.gz" }
    $CodeUrl = if ($IsOSWindows) { "https://update.code.visualstudio.com/${VsCodeVer}/win32-x64-archive/stable" } elseif ($IsOSMac) { "https://update.code.visualstudio.com/${VsCodeVer}/darwin-universal/stable" } else { "https://update.code.visualstudio.com/${VsCodeVer}/linux-x64/stable" }
    
    $ArchivePath = Join-Path $TmpDir $CodeAsset
    Get-File -Url $CodeUrl -OutFile $ArchivePath
    
    $ExtractTarget = Join-Path $TmpDir "code_out"
    Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $CodeDir
    New-Item -ItemType Directory -Path (Join-Path $CodeDir "data") -Force | Out-Null
}

# Cleanup transient downloads
if (Test-Path $TmpDir) {
    Write-ClauseLog "Cleaning up temporary extraction folder: $TmpDir" -Level DEBUG
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# WINDOWS PROFILE CLEANUP (GRACEFULLY SKIPPED ON POSIX)
# ---------------------------------------------------------------------------
if ($IsOSWindows) {
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
    Write-ClauseLog "Syncing Mise Nushell overlay..." -Level INFO
    try {
        & $NuBin -c "^'$MiseBin' activate nu | save '$MiseNu' --force"
    } catch {
        Write-ClauseLog "Failed to sync Mise overlay with Nushell: $_" -Level ERROR
    }
} else {
    Write-ClauseLog "Skipping Mise overlay sync (MiseBin or NuBin not found)" -Level WARN
}

# ==============================================================================
# STAGE 2: NUSHELL HANDOFF (CLI, CI/CD NON-INTERACTIVE, & TTY ROUTING)
# ==============================================================================
Set-Location -Path $ProjectRoot

$EnvNu    = Join-Path $ProjectRoot "scripts/cli/nu/core/boot.nu"
$ConfigNu = Join-Path $NuConfigDir "config.nu"
$IsNonInteractive = [Console]::IsInputRedirected -or $env:CI -eq "true"

Write-ClauseLog "Performing Nushell handoff (Interactive=$(-not $IsNonInteractive))..." -Level INFO

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
        Write-ClauseLog "Environment file missing at $EnvNu. Booting default Nushell shell..." -Level WARN
        & $NuBin
    }
} else {
    Write-ClauseLog "Nushell executable missing at $NuBin." -Level FATAL
    exit 1
}