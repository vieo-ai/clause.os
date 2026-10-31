# cx.ps1 - Native PowerShell Entry Point & Microkernel Bootloader for ClauseOS
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = 'Stop'

# ==============================================================================
# RESOLVE ROOT & LOAD CANONICAL ENVIRONMENT
# ==============================================================================
$ProjectRoot = if ($env:CLAUSE_PROJECT_ROOT) { $env:CLAUSE_PROJECT_ROOT } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$env:CLAUSE_PROJECT_ROOT = $ProjectRoot

# Ingest the Single Source of Truth
$EnvScript = Join-Path $ProjectRoot "scripts\cli\pwsh\config\env.ps1"
if (-not (Test-Path $EnvScript)) {
    throw "[ClauseOS] Critical: Canonical environment file missing at $EnvScript"
}
. $EnvScript

# Detect OS flags
$IsOSWindows = $IsWindows -or $env:OS -eq "Windows_NT"

# Ensure hermetic AppData trees exist so nu and cosign/TUF never hit missing dirs
if ($IsOSWindows) {
    $WinRoaming = Join-Path $env:CLAUSE_HOME "AppData\Roaming"
    $WinLocal   = Join-Path $env:CLAUSE_HOME "AppData\Local"
    @($WinRoaming, $WinLocal) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
    }
}

$IsOSMac   = $IsMacOS -or ($PSVersionTable.OS -like "*Darwin*")
$IsOSLinux = -not $IsOSWindows -and -not $IsOSMac

# ==============================================================================
# LOGGING SYSTEM INITIALIZATION
# ==============================================================================
$LogDir  = $env:CLAUSE_LOGS_DIR
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
Write-ClauseLog "Context: Root=$ProjectRoot | Home=$env:CLAUSE_HOME | OS(Windows=$IsOSWindows, Linux=$IsOSLinux, Mac=$IsOSMac)" -Level DEBUG

# ==============================================================================
# TARGET DIRECTORY PROVISIONING
# ==============================================================================
$LocalBin    = $env:CLAUSE_BIN_DIR
$AppDir      = $env:CLAUSE_APPS_DIR
$TmpDir      = $env:CLAUSE_TEMP_DIR
$Manifest    = Join-Path $ProjectRoot ".clause.toml"
$NuConfigDir = $env:NU_CONFIG_DIR

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
            $NativeTar = if (Test-Path "/usr/bin/tar") { "/usr/bin/tar" } elseif (Test-Path "/bin/tar") { "/bin/tar" } else { "tar" }
            & $NativeTar -xf "$ArchivePath" -C "$DestinationPath"
            if ($LASTEXITCODE -ne 0) { throw "$NativeTar failed with code $LASTEXITCODE" }
        }
    } catch {
        Write-ClauseLog "Archive extraction failed for '$ArchivePath': $_" -Level ERROR
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

# Provision Core System Directories
@($LocalBin, $AppDir, $TmpDir, $NuConfigDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
}

# ==============================================================================
# TWO-BINARY SEEDING (MISE & NU)
# ==============================================================================
$ExeExt  = if ($IsOSWindows) { ".exe" } else { "" }
$MiseBin = Join-Path $LocalBin "mise$ExeExt"
$NuBin   = Join-Path $LocalBin "nu$ExeExt"

# 1. Mise Seeding
if (-not (Test-Path $MiseBin)) {
    $MiseVersion = Get-TomlValue -Content $TomlContent -Key "mise"
    if (-not $MiseVersion) {
        Write-ClauseLog "Missing required version definition for 'mise' in .clause.toml" -Level FATAL
        throw "[ClauseOS] Error: Missing required version definition for 'mise' in .clause.toml"
    }

    $CleanMiseVer = $MiseVersion.TrimStart('v')
    Write-ClauseLog "Seeding Mise (v$CleanMiseVer) into $LocalBin..." -Level INFO

    if ($IsOSWindows) {
        $MiseAsset    = "mise-v${CleanMiseVer}-windows-x64.zip"
        $MiseUrl      = "https://github.com/jdx/mise/releases/download/v${CleanMiseVer}/${MiseAsset}"
        $MiseDownload = Join-Path $TmpDir $MiseAsset
        $MiseExtract  = Join-Path $TmpDir "mise_extracted"

        Get-File -Url $MiseUrl -OutFile $MiseDownload
        Expand-HermeticArchive -ArchivePath $MiseDownload -DestinationPath $MiseExtract

        # Move all unpacked binaries (mise.exe, mise-shim.exe, etc.) into $LocalBin
        Get-ChildItem -Path $MiseExtract -Filter "*.exe" -Recurse | ForEach-Object {
            Move-Item -Path $_.FullName -Destination $LocalBin -Force
        }
    } else {
        $MiseUrl = if ($IsOSMac) {
            "https://github.com/jdx/mise/releases/download/v${CleanMiseVer}/mise-v${CleanMiseVer}-macos-x64"
        } else {
            "https://github.com/jdx/mise/releases/download/v${CleanMiseVer}/mise-v${CleanMiseVer}-linux-x64"
        }

        Get-File -Url $MiseUrl -OutFile $MiseBin
        Set-PosixExecutable -FilePath $MiseBin
    }
}

# 2. Nushell Seeding
if (-not (Test-Path $NuBin)) {
    $NuVersion = Get-TomlValue -Content $TomlContent -Key "nu"
    if (-not $NuVersion) {
        Write-ClauseLog "Missing required version definition for 'nu' in .clause.toml" -Level FATAL
        throw "[ClauseOS] Error: Missing required version definition for 'nu' in .clause.toml"
    }

    $CleanNuVer = $NuVersion.TrimStart('v')
    Write-ClauseLog "Seeding Nushell (v$CleanNuVer) into $LocalBin..." -Level INFO

    $NuAsset = if ($IsOSWindows) {
        "nu-${CleanNuVer}-x86_64-pc-windows-msvc.zip"
    } elseif ($IsOSMac) {
        "nu-${CleanNuVer}-x86_64-apple-darwin.tar.gz"
    } else {
        "nu-${CleanNuVer}-x86_64-unknown-linux-musl.tar.gz"
    }

    $NuUrl      = "https://github.com/nushell/nushell/releases/download/${CleanNuVer}/${NuAsset}"
    $NuDownload = Join-Path $TmpDir $NuAsset
    $NuExtract  = Join-Path $TmpDir "nu_extracted"

    Get-File -Url $NuUrl -OutFile $NuDownload
    Expand-HermeticArchive -ArchivePath $NuDownload -DestinationPath $NuExtract

    $ExtractedNu = Get-ChildItem -Path $NuExtract -Filter "nu$ExeExt" -Recurse | Select-Object -First 1
    if (-not $ExtractedNu) {
        Write-ClauseLog "Failed to locate extracted nu binary in $NuExtract" -Level FATAL
        throw "[ClauseOS] Error: Could not find nu executable in extracted archive"
    }

    Move-Item -Path $ExtractedNu.FullName -Destination $NuBin -Force
    Set-PosixExecutable -FilePath $NuBin
}

# Cleanup transient downloads
if (Test-Path $TmpDir) {
    Write-ClauseLog "Cleaning up temporary extraction folder: $TmpDir" -Level DEBUG
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path $env:CLAUSE_TEMP_DIR) {
    Remove-Item -Path $env:CLAUSE_TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $env:CLAUSE_TEMP_DIR | Out-Null

# Windows Profile Attribute Protection
if ($IsOSWindows) {
    if (Get-Command attrib.exe -ErrorAction SilentlyContinue) {
        attrib.exe +h "$($env:CLAUSE_HOME)" 2>$null
    }
}

# ==============================================================================
# GENERATE NUSHELL MISE ACTIVATION OVERLAY
# ==============================================================================
$MiseNu = Join-Path $NuConfigDir "mise.nu"

if ((Test-Path $MiseBin) -and (Test-Path $NuBin)) {
    Write-ClauseLog "Syncing Mise Nushell overlay..." -Level INFO
    try {
        & $NuBin -c "^'$MiseBin' activate nu | save '$MiseNu' --force"
    } catch {
        Write-ClauseLog "Failed to sync Mise overlay with Nushell: $_" -Level ERROR
    }
}

# ==============================================================================
# STAGE 2: TOOLCHAIN INSTALLATION (MISE)
# ==============================================================================
Write-ClauseLog "Finalizing ClauseOS toolchain installation..." -Level INFO
& $MiseBin install
if ($LASTEXITCODE -ne 0) {
    Write-ClauseLog "Mise installation failed with exit code $LASTEXITCODE" -Level FATAL
    exit $LASTEXITCODE
}

# Ensure Mise shims/binaries are present in current session PATH for downstream recipes
$MiseShimRel = if ($IsOSWindows) { "AppData\Local\mise\shims" } else { ".local/share/mise/shims" }
$MiseShims   = Join-Path $env:CLAUSE_HOME $MiseShimRel

if (Test-Path $MiseShims) {
    $PathSep = if ($IsOSWindows) { ";" } else { ":" }
    $env:PATH = "$MiseShims$PathSep$env:PATH"
}

# ==============================================================================
# STAGE 3: NUSHELL HANDOFF (CLI, CI/CD NON-INTERACTIVE, & TTY ROUTING)
# ==============================================================================
Set-Location -Path $ProjectRoot

$EnvNu    = Join-Path $ProjectRoot "scripts/cli/nu/core/boot.nu"
$ConfigNu = Join-Path $NuConfigDir "config.nu"
$IsNonInteractive = [Console]::IsInputRedirected -or $env:CI -eq "true"

Write-ClauseLog "Performing Nushell handoff (Interactive=$(-not $IsNonInteractive))..." -Level INFO

$PassedArgs = if ($ScriptArgs) { $ScriptArgs } else { $args }

if (Test-Path $NuBin) {
    if (Test-Path $EnvNu) {
        if ($PassedArgs.Count -gt 0) {
            $CommandString = $PassedArgs -join " "
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