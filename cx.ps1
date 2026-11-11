# cx.ps1 - Native PowerShell Entry Point & Microkernel Bootloader for ClauseOS
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = 'Stop'

# ==============================================================================
# RESOLVE ROOT & LOAD CANONICAL ENVIRONMENT FROM .ENV (SSOT)
# ==============================================================================
# 1. Base Anchors
$ProjectRoot = if ($env:CLAUSE_PROJECT_ROOT) { $env:CLAUSE_PROJECT_ROOT } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$env:CLAUSE_PROJECT_ROOT = $ProjectRoot

# Ingest the Single Source of Truth (.env file)
$DotEnvPath = Join-Path $ProjectRoot ".env"
if (-not (Test-Path $DotEnvPath)) {
    throw "[ClauseOS] Critical: Canonical environment file missing at $DotEnvPath"
}

Get-Content -Path $DotEnvPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not ($line.StartsWith("#")) -and ($line -match '^([^=]+)=(.*)$')) {
        $key = $matches[1].Trim()
        $val = $matches[2].Trim().Trim('"').Trim("'")
        [Environment]::SetEnvironmentVariable($key, $val, 'Process')
    }
}

# 2. Confinement Anchors
$ClauseHome = Join-Path $ProjectRoot $(if ($env:CLAUSE_HOME) { $env:CLAUSE_HOME } else { ".home" })
$env:CLAUSE_HOME = $ClauseHome
$env:HOME        = $ClauseHome
$env:USERPROFILE = $ClauseHome

# 3. Platform Hierarchy
$IsOSWindows = $IsWindows -or $env:OS -eq "Windows_NT"
$IsOSMac     = $IsMacOS -or ($PSVersionTable.OS -like "*Darwin*")
$IsOSLinux   = -not $IsOSWindows -and -not $IsOSMac

if ($IsOSWindows) {
    # 1. Clean up POSIX XDG variables so Windows runtimes (like Nushell) don't trip
    @(
        'XDG_CONFIG_HOME',
        'XDG_DATA_HOME',
        'XDG_STATE_HOME',
        'XDG_CACHE_HOME',
        'POSIX_CLAUSE_BIN_DIR',
        'POSIX_CLAUSE_APPS_DIR',
        'POSIX_CLAUSE_LOGS_DIR'
    ) | ForEach-Object {
        [Environment]::SetEnvironmentVariable($_, $null, 'Process')
    }
    
    # Windows Native NT Layout inside .home
    $WinLocal   = Join-Path $ProjectRoot $env:WIN_LOCALAPPDATA
    $WinRoaming = Join-Path $ProjectRoot $env:WIN_APPDATA

    $env:LOCALAPPDATA = $WinLocal
    $env:APPDATA      = $WinRoaming

    $env:CLAUSE_BIN_DIR   = Join-Path $ProjectRoot $env:WIN_CLAUSE_BIN_DIR
    $env:CLAUSE_APPS_DIR  = Join-Path $ProjectRoot $env:WIN_CLAUSE_APPS_DIR
    $env:CLAUSE_CACHE_DIR = Join-Path $ProjectRoot $env:WIN_CLAUSE_CACHE_DIR
    $env:CLAUSE_TEMP_DIR  = Join-Path $ProjectRoot $env:WIN_CLAUSE_TEMP_DIR
    $env:CLAUSE_LOGS_DIR  = Join-Path $ProjectRoot $env:WIN_CLAUSE_LOGS_DIR

    # Mise paths on Windows
    $env:MISE_DATA_DIR   = Join-Path $WinLocal "mise"
    $env:MISE_CONFIG_DIR = Join-Path $WinRoaming "mise"
    $env:MISE_STATE_DIR  = Join-Path $WinLocal "mise\state"
    $env:MISE_CACHE_DIR  = Join-Path $WinLocal "mise\cache"
    $env:MISE_LOG_FILE   = Join-Path $WinLocal "mise\logs\mise.log"
    $env:GH_CONFIG_DIR   = Join-Path $WinRoaming "GitHub CLI"

    # Ensure hermetic AppData trees exist so nu and cosign/TUF never hit missing dirs
    @($WinRoaming, $WinLocal) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
    }
} else {
    # POSIX XDG Standards inside .home
    $env:XDG_CONFIG_HOME = Join-Path $ProjectRoot $env:XDG_CONFIG_HOME
    $env:XDG_DATA_HOME   = Join-Path $ProjectRoot $env:XDG_DATA_HOME
    $env:XDG_STATE_HOME  = Join-Path $ProjectRoot $env:XDG_STATE_HOME
    $env:XDG_CACHE_HOME  = Join-Path $ProjectRoot $env:XDG_CACHE_HOME

    $env:CLAUSE_BIN_DIR   = Join-Path $ProjectRoot $env:POSIX_CLAUSE_BIN_DIR
    $env:CLAUSE_APPS_DIR  = Join-Path $ProjectRoot $env:POSIX_CLAUSE_APPS_DIR
    $env:CLAUSE_CACHE_DIR = $env:XDG_CACHE_HOME
    $env:CLAUSE_TEMP_DIR  = Join-Path $env:XDG_CACHE_HOME "tmp_bootstrap"
    $env:CLAUSE_LOGS_DIR  = Join-Path $ProjectRoot $env:POSIX_CLAUSE_LOGS_DIR

    # Mise paths on POSIX
    $env:MISE_DATA_DIR   = Join-Path $env:XDG_DATA_HOME "mise"
    $env:MISE_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME "mise"
    $env:MISE_STATE_DIR  = Join-Path $env:XDG_STATE_HOME "mise"
    $env:MISE_CACHE_DIR  = Join-Path $env:XDG_CACHE_HOME "mise"
    $env:MISE_LOG_FILE   = Join-Path $env:XDG_STATE_HOME "mise\logs\mise.log"
    $env:GH_CONFIG_DIR   = Join-Path $env:XDG_CONFIG_HOME "gh"
}

# 4. Invariant Directories & Hermetic SSH Containment
$SshDir = Join-Path $ClauseHome ".ssh"
@( $env:CLAUSE_CACHE_DIR, $env:CLAUSE_BIN_DIR, $SshDir ) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Force -Path $_ | Out-Null
    }
}

$SshConfig  = Join-Path $SshDir "config"
$KnownHosts = Join-Path $SshDir "known_hosts"

# Format with forward slashes for OpenSSH argument parsing
$SshConfigFwd  = $SshConfig.Replace('\', '/')
$KnownHostsFwd = $KnownHosts.Replace('\', '/')

if (Test-Path $SshConfig) {
    $env:GIT_SSH_COMMAND = "ssh -F '$SshConfigFwd' -o UserKnownHostsFile='$KnownHostsFwd'"
} else {
    $KeyEd  = (Join-Path $SshDir "id_ed25519").Replace('\', '/')
    $KeyRsa = (Join-Path $SshDir "id_rsa").Replace('\', '/')
    $env:GIT_SSH_COMMAND = "ssh -i '$KeyEd' -i '$KeyRsa' -o UserKnownHostsFile='$KnownHostsFwd'"
}

# 5. Identity & Tool Routing
$env:GIT_CONFIG_GLOBAL = Join-Path $ProjectRoot $env:GIT_CONFIG_GLOBAL
$env:NU_CONFIG_DIR     = Join-Path $ProjectRoot $env:NU_CONFIG_DIR
$env:PULUMI_HOME       = Join-Path $ProjectRoot $env:PULUMI_HOME

# 6. Global PATH Management (Prepend Stage 0 Binaries Only)
if ($env:PATH -notlike "*$($env:CLAUSE_BIN_DIR)*") {
    $PathSep = if ($IsOSWindows) { ";" } else { ":" }
    $env:PATH = "$($env:CLAUSE_BIN_DIR)$PathSep$env:PATH"
}

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

# ==============================================================================
# CLEANUP TRANSIENT DOWNLOADS & EXTRACTIONS
# ==============================================================================
# 1. Clean contents inside TmpDir without removing the folder itself
if (Test-Path $TmpDir) {
    Write-ClauseLog "Cleaning up temporary extraction folder: $TmpDir" -Level DEBUG
    Get-ChildItem -Path $TmpDir -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
}

# 2. Clean contents inside CLAUSE_TEMP_DIR without removing the root directory
if ($env:CLAUSE_TEMP_DIR -and (Test-Path $env:CLAUSE_TEMP_DIR)) {
    Get-ChildItem -Path $env:CLAUSE_TEMP_DIR -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 3. Guarantee that TEMP and TMP exist on disk for all child cmd.exe / git processes
@($env:CLAUSE_TEMP_DIR, $env:TEMP, $env:TMP) | Where-Object { $_ -and -not (Test-Path $_) } | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}

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
        & $NuBin -c "with-env { MISE_DISABLE_TOOLS: '1' } { ^'$MiseBin' activate nu | save '$MiseNu' --force }"
    } catch {
        Write-ClauseLog "Failed to sync Mise overlay with Nushell: $_" -Level ERROR
    }
}

# ==============================================================================
# STAGE 2: TOOLCHAIN INSTALLATION & HEALTH VERIFICATION (MISE)
# ==============================================================================
Write-ClauseLog "Finalizing ClauseOS toolchain installation..." -Level INFO
& $MiseBin install --yes
if ($LASTEXITCODE -ne 0) {
    Write-ClauseLog "Mise installation failed with exit code $LASTEXITCODE" -Level FATAL
    exit $LASTEXITCODE
}

# Ensure Mise shims/binaries are present in current session PATH
$MiseShimRel = if ($IsOSWindows) { "AppData\Local\mise\shims" } else { ".local/share/mise/shims" }
$MiseShims   = Join-Path $env:CLAUSE_HOME $MiseShimRel

if (Test-Path $MiseShims) {
    $PathSep = if ($IsOSWindows) { ";" } else { ":" }
    $env:PATH = "$MiseShims$PathSep$env:PATH"
}

# --- Direct Filesystem Probe for Engine Directories ---
$RequiredTools = @("comfyui", "lemonade", "code", "fastflowlm", "unsloth")
$MissingTools  = @()

$InstallsRel       = if ($IsOSWindows) { "AppData\Local\mise\installs" } else { ".local/share/mise/installs" }
$MiseInstallsBase  = Join-Path $env:CLAUSE_HOME $InstallsRel

Write-ClauseLog "Probing tool installations at: $MiseInstallsBase" -Level DEBUG

foreach ($Tool in $RequiredTools) {
    $ToolDir = Join-Path $MiseInstallsBase $Tool
    $Installed = $false

    if (Test-Path $ToolDir) {
        # Check if there is at least one version subdirectory inside
        $Versions = Get-ChildItem -Path $ToolDir -Directory -ErrorAction SilentlyContinue
        if ($Versions -and $Versions.Count -gt 0) {
            $Installed = $true
        }
    }

    if (-not $Installed) {
        $MissingTools += $Tool
    }
}

if ($MissingTools.Count -gt 0) {
    Write-ClauseLog "Missing toolchain engines detected: $($MissingTools -join ', '). Re-executing mise install..." -Level WARN
    & $MiseBin install --yes
    if ($LASTEXITCODE -ne 0) {
        Write-ClauseLog "Mise retry installation failed with exit code $LASTEXITCODE" -Level FATAL
        exit $LASTEXITCODE
    }
} else {
    Write-ClauseLog "All engines verified successfully." -Level INFO
}

# ==============================================================================
# STAGE 2.5: REBAR3 WINDOWS CMD TRAMPOLINE GENERATION
# ==============================================================================
if ($IsOSWindows) {
    Write-ClauseLog "Checking Rebar3 Windows launcher configuration..." -Level DEBUG
    
    $MiseInstallsBase = Join-Path $env:CLAUSE_HOME "AppData\Local\mise\installs"
    $Rebar3Dir = Join-Path $MiseInstallsBase "rebar"

    if (Test-Path $Rebar3Dir) {
        # Scan all installed rebar3 versions
        Get-ChildItem -Path $Rebar3Dir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $VersionDir = $_.FullName
            $RebarFile = Join-Path $VersionDir "rebar3"
            $RebarCmd  = Join-Path $VersionDir "rebar3.cmd"

            # If the raw rebar3 escript exists but lacks a Windows launcher, create it
            if ((Test-Path $RebarFile) -and (-not (Test-Path $RebarCmd))) {
                Write-ClauseLog "Generating rebar3.cmd launcher in: $VersionDir" -Level INFO
                
                # Idiomatic OTP escript trampoline matching standard Erlang rebar3 distribution
                $CmdContent = @"
@echo off
setlocal
set PATH=%~dp0;%PATH%
escript "%~dp0rebar3" %*
"@
                Set-Content -LiteralPath $RebarCmd -Value $CmdContent -Encoding ASCII
            }
        }
    }

    # Also place a trampoline into the primary ClauseOS bin folder if rebar3 is present
    $ClauseBin = $env:CLAUSE_BIN_DIR
    if ($ClauseBin -and (Test-Path $ClauseBin)) {
        $RootRebar = Join-Path $ClauseBin "rebar3"
        $RootRebarCmd = Join-Path $ClauseBin "rebar3.cmd"
        if ((Test-Path $RootRebar) -and (-not (Test-Path $RootRebarCmd))) {
            $CmdContent = @"
@echo off
setlocal
set PATH=%~dp0;%PATH%
escript "%~dp0rebar3" %*
"@
            Set-Content -LiteralPath $RootRebarCmd -Value $CmdContent -Encoding ASCII
        }
    }
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