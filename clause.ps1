# clause.ps1 - Windows Stage 0 Microkernel & Confined Profile Bootloader
# Compatible with legacy Windows PowerShell 5.1+
$ErrorActionPreference = 'Stop'

$ProjectRoot = if ($env:CLAUSE_PROJECT_ROOT) { $env:CLAUSE_PROJECT_ROOT } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# ==============================================================================
# PRE-BOOT ENVIRONMENT LOCKING & ATTRIBUTE CLEANUP
# ==============================================================================
$EnvScript = Join-Path $ProjectRoot ".config\pwsh\env.ps1"
if (Test-Path $EnvScript) {
    . $EnvScript
}

# Automatically apply Hidden attribute to top-level dot folders on Windows
Get-ChildItem -Path $ProjectRoot -Directory -Filter ".*" | ForEach-Object {
    if (-not ($_.Attributes -match "Hidden")) {
        $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
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
        if ($LASTEXITCODE -ne 0) {
            throw "[ClauseOS] Download failed via curl.exe for URL: $Url"
        }
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
        if ($LASTEXITCODE -ne 0) {
            throw "[ClauseOS] Archive extraction failed via tar.exe for: $ArchivePath"
        }
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

# ==============================================================================
# STAGE 0: CORE SYSTEM ENGINE SEEDING
# ==============================================================================

# 1. Mise Engine -> .local\bin\
$MiseBin = Join-Path $LocalBin "mise.exe"
if (-not (Test-Path $MiseBin)) {
    Write-Host "[ClauseOS Stage 0] Pre-seeding Mise (v${MiseVer}) into .local\bin\..." -ForegroundColor Cyan
    $MiseAsset = "mise-v${MiseVer}-windows-x64.zip"
    $ZipPath = Join-Path $TmpDir $MiseAsset
    Get-File -Url "https://github.com/jdx/mise/releases/download/v${MiseVer}/$MiseAsset" -OutFile $ZipPath
    
    $ExtractTarget = Join-Path $TmpDir "mise_out"
    Expand-HermeticArchive -ArchivePath $ZipPath -DestinationPath $ExtractTarget
    $FoundMise = Get-ChildItem -Path $ExtractTarget -Filter "mise.exe" -Recurse | Select-Object -First 1
    if ($FoundMise) {
        Get-ChildItem -Path $FoundMise.DirectoryName | Move-Item -Destination $LocalBin -Force
    }
}

# 2. Just Task Scheduler -> .local\bin\
$JustBin = Join-Path $LocalBin "just.exe"
if (-not (Test-Path $JustBin)) {
    Write-Host "[ClauseOS Stage 0] Pre-seeding Just (v${JustVer}) into .local\bin\..." -ForegroundColor Cyan
    $JustAsset = "just-${JustVer}-x86_64-pc-windows-msvc.zip"
    $ZipPath = Join-Path $TmpDir $JustAsset
    Get-File -Url "https://github.com/casey/just/releases/download/${JustVer}/$JustAsset" -OutFile $ZipPath
    
    $ExtractTarget = Join-Path $TmpDir "just_out"
    Expand-HermeticArchive -ArchivePath $ZipPath -DestinationPath $ExtractTarget
    $FoundJust = Get-ChildItem -Path $ExtractTarget -Filter "just.exe" -Recurse | Select-Object -First 1
    if ($FoundJust) {
        Move-Item -Path $FoundJust.FullName -Destination $LocalBin -Force
    }
}

# 3. Nushell Shell Engine -> .local\bin\
$NuBin = Join-Path $LocalBin "nu.exe"
if (-not (Test-Path $NuBin)) {
    Write-Host "[ClauseOS Stage 0] Pre-seeding Nushell (v${NuVer}) into .local\bin\..." -ForegroundColor Cyan
    $NuAsset = "nu-${NuVer}-x86_64-pc-windows-msvc.zip"
    $ZipPath = Join-Path $TmpDir $NuAsset
    Get-File -Url "https://github.com/nushell/nushell/releases/download/${NuVer}/$NuAsset" -OutFile $ZipPath
    
    $ExtractTarget = Join-Path $TmpDir "nu_out"
    Expand-HermeticArchive -ArchivePath $ZipPath -DestinationPath $ExtractTarget
    $FoundNu = Get-ChildItem -Path $ExtractTarget -Filter "nu.exe" -Recurse | Select-Object -First 1
    if ($FoundNu) {
        Get-ChildItem -Path $FoundNu.DirectoryName | Move-Item -Destination $LocalBin -Force
    }
}

# ==============================================================================
# STAGE 1: PORTABLE APPS & AI COMPONENT SEEDING
# ==============================================================================

# 4. Lemonade GPU Engine -> .local\app\lemonade\
$LemonadeCheck = Get-ChildItem -Path $InferenceGpuDir -Filter "*.exe" -ErrorAction SilentlyContinue
if (-not $LemonadeCheck) {
    Write-Host "[ClauseOS Stage 1] Seeding Lemonade GPU Engine (${LemonadeTag})..." -ForegroundColor Cyan
    $LemonadeAsset = "lemonade-embeddable-${LemonadeClean}-windows-x64.zip"
    $ZipPath = Join-Path $TmpDir $LemonadeAsset
    Get-File -Url "https://github.com/lemonade-sdk/lemonade/releases/download/${LemonadeTag}/${LemonadeAsset}" -OutFile $ZipPath
    
    $ExtractTarget = Join-Path $TmpDir "lemonade_out"
    Expand-HermeticArchive -ArchivePath $ZipPath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $InferenceGpuDir
}

# 5. FastFlowLM NPU Engine -> .local\app\fastflowlm\
$FastFlowCheck = Get-ChildItem -Path $InferenceNpuDir -Filter "*.exe" -ErrorAction SilentlyContinue
if (-not $FastFlowCheck) {
    Write-Host "[ClauseOS Stage 1] Seeding FastFlowLM NPU Engine (${FastFlowTag})..." -ForegroundColor Cyan
    $FastFlowAsset = "fastflowlm_${FastFlowClean}_windows_amd64.zip"
    $ZipPath = Join-Path $TmpDir $FastFlowAsset
    Get-File -Url "https://github.com/ROCm/FastFlowLM/releases/download/${FastFlowTag}/${FastFlowAsset}" -OutFile $ZipPath
    
    $ExtractTarget = Join-Path $TmpDir "fastflow_out"
    Expand-HermeticArchive -ArchivePath $ZipPath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $InferenceNpuDir
}

# 6. APM (Agent Package Manager) -> .local\app\apm\
$ApmBin = Join-Path $ApmDir "apm.exe"
if (-not (Test-Path $ApmBin)) {
    Write-Host "[ClauseOS Stage 1] Seeding Agent Package Manager (${ApmTag})..." -ForegroundColor Cyan
    $ApmAsset = "apm-windows-x86_64.zip"
    $ZipPath = Join-Path $TmpDir $ApmAsset
    Get-File -Url "https://github.com/microsoft/apm/releases/download/${ApmTag}/${ApmAsset}" -OutFile $ZipPath
    
    $ExtractTarget = Join-Path $TmpDir "apm_out"
    Expand-HermeticArchive -ArchivePath $ZipPath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $ApmDir
}

# 7. VS Code Portable -> .local\app\vscode\
$CodeBin = Join-Path (Join-Path $CodeDir "bin") "code.cmd"
if (-not (Test-Path $CodeBin)) {
    Write-Host "[ClauseOS Stage 1] Seeding VS Code Portable Engine (v${VsCodeVer})..." -ForegroundColor Cyan
    $CodeAsset = "vscode-win32-x64-${VsCodeVer}.zip"
    $ZipPath = Join-Path $TmpDir $CodeAsset
    Get-File -Url "https://update.code.visualstudio.com/${VsCodeVer}/win32-x64-archive/stable" -OutFile $ZipPath
    
    $ExtractTarget = Join-Path $TmpDir "code_out"
    Expand-HermeticArchive -ArchivePath $ZipPath -DestinationPath $ExtractTarget
    Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $CodeDir
    
    # Initialize Portable Data directory
    New-Item -ItemType Directory -Path (Join-Path $CodeDir "data") -Force | Out-Null
}

# Cleanup transient downloads
if (Test-Path $TmpDir) { Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue }

# ==============================================================================
# STAGE 2: PID 1 NUSHELL HANDOFF
# ==============================================================================
Write-Host "[ClauseOS] Kernel ready. Executing Nushell init..." -ForegroundColor Green

& $NuBin --config "$NuConfigDir\config.nu" --env-config "$NuConfigDir\env.nu"