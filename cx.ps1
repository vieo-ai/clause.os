# cx.ps1 - Native PowerShell Entry Point & Microkernel Bootloader for ClauseOS
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = 'Stop'

# ==============================================================================
# RESOLVE ROOT & LOAD CANONICAL ENVIRONMENT FROM MODULAR TOML (SSOT)
# ==============================================================================
# 1. Base Anchors
$ProjectRoot = if ($env:CLAUSE_PROJECT_ROOT) { $env:CLAUSE_PROJECT_ROOT } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$env:CLAUSE_PROJECT_ROOT = $ProjectRoot
$CallerMiseEnv = $env:MISE_ENV

$IsOSWindows = $IsWindows -or $env:OS -eq "Windows_NT"
$IsOSMac     = $IsMacOS -or ($PSVersionTable.OS -like "*Darwin*")
$IsOSLinux   = -not $IsOSWindows -and -not $IsOSMac
$PlatformKey = if ($IsOSWindows) { "windows" } else { "posix" }

# Ingest the Single Source of Truth (config/env/*.toml modules)
$EnvConfigDir = Join-Path $ProjectRoot "config\env"
if (-not (Test-Path -LiteralPath $EnvConfigDir -PathType Container)) {
    throw "[ClauseOS] Critical: Modular environment directory missing at $EnvConfigDir"
}

$TomlModules = Get-ChildItem -Path $EnvConfigDir -Filter "*.toml" | Sort-Object Name
if (-not $TomlModules -or $TomlModules.Count -eq 0) {
    throw "[ClauseOS] Critical: No TOML environment modules found in $EnvConfigDir"
}

$RawAnchors   = [ordered]@{}
$RawEnv       = [ordered]@{}
$RawProvision = [ordered]@{}

# Pass 1: Ingest raw key/value definitions for the active platform only
foreach ($Module in $TomlModules) {
    $CurrentSection = ""

    foreach ($RawLine in [System.IO.File]::ReadAllLines($Module.FullName)) {
        $Line = $RawLine.Trim()

        if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith('#')) {
            continue
        }

        if ($Line -match '^\[([a-zA-Z0-9_.-]+)\]$') {
            $CurrentSection = $Matches[1]
            continue
        }

        $EqIdx = $Line.IndexOf('=')
        if ($EqIdx -lt 1) { continue }

        $Key = $Line.Substring(0, $EqIdx).Trim()
        $Val = $Line.Substring($EqIdx + 1).Trim()

        if (($Val.StartsWith('"') -and $Val.EndsWith('"') -and $Val.Length -ge 2) -or
            ($Val.StartsWith("'") -and $Val.EndsWith("'") -and $Val.Length -ge 2)) {
            $Val = $Val.Substring(1, $Val.Length - 2)
        } else {
            $Val = ($Val -replace '\s+#.*$', '').Trim()
        }

        if ($CurrentSection -eq "anchors.$PlatformKey") {
            $RawAnchors[$Key] = $Val
        } elseif ($CurrentSection -eq "env" -or $CurrentSection -eq "env.$PlatformKey") {
            $RawEnv[$Key] = $Val
        } elseif ($CurrentSection -eq "provision" -or $CurrentSection -eq "provision.$PlatformKey") {
            $RawProvision[$Key] = $Val
        }
    }
}

function Normalize-ClausePath {
    param([string]$Value)

    if ([string]::IsNullOrEmpty($Value)) {
        return $Value
    }

    # Skip URLs
    if ($Value -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        return $Value
    }

    # Already rooted (POSIX /..., Windows C:\... or C:/..., UNC \\...)
    if ($Value.StartsWith('/') -or $Value.StartsWith('\') -or ($Value -match '^[a-zA-Z]:')) {
        if ($IsOSWindows -and $Value.StartsWith($ProjectRoot)) {
            return ($Value -replace '/', '\')
        }
        return $Value
    }

    # Resolve any relative path containing '/' or '\', plus root dotfiles (.home, .clause.toml)
    if ($Value.Contains('/') -or $Value.Contains('\') -or
        ($Value -match '^\.[a-zA-Z0-9_.-]+$' -and $Value -ne ".")) {
        $Rel = if ($IsOSWindows) { $Value -replace '/', '\' } else { $Value }
        return (Join-Path $ProjectRoot $Rel)
    }

    return $Value
}

function Expand-ClauseSymbolTable {
    param(
        [System.Collections.IDictionary]$TargetTable,
        [System.Collections.IDictionary[]]$LookupTables
    )

    for ($Pass = 0; $Pass -lt 8; $Pass++) {
        $Changed = $false
        $Keys = @($TargetTable.Keys)

        foreach ($K in $Keys) {
            $CurrentVal = $TargetTable[$K]
            if ([string]::IsNullOrEmpty($CurrentVal) -or ($CurrentVal -notlike '*${*}*')) {
                continue
            }

            $NextVal = [regex]::Replace($CurrentVal, '\$\{([a-zA-Z_][a-zA-Z0-9_]*)\}', {
                param($Match)
                $RefName = $Match.Groups[1].Value

                foreach ($Table in $LookupTables) {
                    if ($Table.Contains($RefName)) {
                        return $Table[$RefName]
                    }
                }

                $ProcVal = [Environment]::GetEnvironmentVariable($RefName, 'Process')
                if ($null -ne $ProcVal) {
                    return $ProcVal
                }

                return $Match.Value
            })

            if ($NextVal -ne $CurrentVal) {
                $TargetTable[$K] = $NextVal
                $Changed = $true
            }
        }

        if (-not $Changed) { break }
    }
}

# Pass 2: Resolve anchors first, then env, then provision targets
Expand-ClauseSymbolTable -TargetTable $RawAnchors -LookupTables @($RawAnchors)
foreach ($K in @($RawAnchors.Keys)) {
    $RawAnchors[$K] = Normalize-ClausePath -Value $RawAnchors[$K]
}

Expand-ClauseSymbolTable -TargetTable $RawEnv -LookupTables @($RawAnchors, $RawEnv)
foreach ($K in @($RawEnv.Keys)) {
    $Resolved = Normalize-ClausePath -Value $RawEnv[$K]
    $RawEnv[$K] = $Resolved
    [Environment]::SetEnvironmentVariable($K, $Resolved, 'Process')
}

# Preserve explicit caller MISE_ENV override if supplied
if (-not [string]::IsNullOrWhiteSpace($CallerMiseEnv)) {
    $env:MISE_ENV = $CallerMiseEnv
}

Expand-ClauseSymbolTable -TargetTable $RawProvision -LookupTables @($RawAnchors, $RawEnv, $RawProvision)
foreach ($K in @($RawProvision.Keys)) {
    $DirPath = Normalize-ClausePath -Value $RawProvision[$K]
    if ($DirPath -and -not (Test-Path -LiteralPath $DirPath)) {
        New-Item -ItemType Directory -Force -Path $DirPath | Out-Null
    }
}

# 2. Confinement Anchors
$ClauseHome = $env:CLAUSE_HOME

# 3. Platform Hierarchy (Windows NT dynamic drive/path fallback)
if ($IsOSWindows) {
    # Resolve HOMEDRIVE & HOMEPATH (use TOML override if provided, else compute)
    if (-not ($env:HOMEDRIVE -and $env:HOMEPATH)) {
        $HomePathSplit = [System.IO.Path]::GetPathRoot($ClauseHome)
        $env:HOMEDRIVE = $HomePathSplit.TrimEnd('\')
        $env:HOMEPATH  = $ClauseHome.Substring($HomePathSplit.Length - 1)
    }

    # Ensure hermetic AppData trees exist so nu and cosign/TUF never hit missing dirs
    @($env:APPDATA, $env:LOCALAPPDATA) | Where-Object { $_ -and -not (Test-Path $_) } | ForEach-Object {
        New-Item -ItemType Directory -Force -Path $_ | Out-Null
    }
}

# 4. Invariant Directories & Hermetic SSH Containment
$SshDir = $env:CLAUSE_SSH_DIR
@( $env:CLAUSE_CACHE_DIR, $env:CLAUSE_BIN_DIR, $SshDir ) | Where-Object { $_ -and -not (Test-Path $_) } | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}

$SshConfig  = $env:CLAUSE_SSH_CONFIG
$KnownHosts = $env:CLAUSE_SSH_KNOWN_HOSTS

# Format with forward slashes for OpenSSH argument parsing
if ($SshConfig -and $KnownHosts) {
    $SshConfigFwd  = $SshConfig.Replace('\', '/')
    $KnownHostsFwd = $KnownHosts.Replace('\', '/')

    if (Test-Path $SshConfig) {
        $env:GIT_SSH_COMMAND = "ssh -F '$SshConfigFwd' -o UserKnownHostsFile='$KnownHostsFwd'"
    } else {
        $KeyEd  = $env:CLAUSE_SSH_KEY_ED25519.Replace('\', '/')
        $KeyRsa = $env:CLAUSE_SSH_KEY_RSA.Replace('\', '/')
        $env:GIT_SSH_COMMAND = "ssh -i '$KeyEd' -i '$KeyRsa' -o UserKnownHostsFile='$KnownHostsFwd'"
    }
}

# 6. Global PATH Management (Prepend Stage 0 Binaries Only)
if ($env:PATH -notlike "*$($env:CLAUSE_BIN_DIR)*") {
    $PathSep = if ($IsOSWindows) { ";" } else { ":" }
    $env:PATH = "$($env:CLAUSE_BIN_DIR)$PathSep$env:PATH"
}

if (-not $IsOSWindows -and $env:HOMEBREW_PREFIX) {
    $BrewBin = Join-Path $env:HOMEBREW_PREFIX "bin"
    if ($env:PATH -notlike "*$BrewBin*") {
        $env:PATH = "$BrewBin`:$env:PATH"
    }
}

# ==============================================================================
# LOGGING SYSTEM INITIALIZATION
# ==============================================================================
$LogDir  = $env:CLAUSE_LOGS_DIR
$LogFile = $env:CLAUSE_BOOTSTRAP_LOG

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
Write-ClauseLog "Context: Root=$ProjectRoot | Home=$env:CLAUSE_HOME | Profile=$($env:MISE_ENV) | OS(Windows=$IsOSWindows, Linux=$IsOSLinux, Mac=$IsOSMac)" -Level DEBUG

# ==============================================================================
# TARGET DIRECTORY PROVISIONING
# ==============================================================================
$LocalBin    = $env:CLAUSE_BIN_DIR
$AppDir      = $env:CLAUSE_APPS_DIR
$TmpDir      = $env:CLAUSE_TEMP_DIR
$Manifest    = $env:CLAUSE_MANIFEST
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
# MODULAR RECIPE DISCOVERY & EXECUTION (STAGE 0 & STAGE 1)
# ==============================================================================
$InstallerDir = $env:INSTALLERS_DIR

if ($InstallerDir -and (Test-Path $InstallerDir)) {
    # Scan for recipes matching: installer_<key>.ps1 or <order>_installer_<key>.ps1
    $Recipes = Get-ChildItem -Path $InstallerDir -Filter "installer_*.ps1" | Sort-Object Name

    foreach ($Recipe in $Recipes) {
        # Extract the TOML key by stripping 'installer_' and '.ps1'
        # e.g., 'installer_fastflowlm.ps1' -> 'fastflowlm'
        # e.g., '01_installer_mise.ps1'   -> 'mise'
        $ToolKey = $Recipe.BaseName -replace '^(\d+_)?installer_', ''

        # Read the pinned version from .clause.toml
        $Version = Get-TomlValue -Content $TomlContent -Key $ToolKey
        if (-not $Version) {
            Write-ClauseLog "Missing required version definition for '$ToolKey' in $Manifest" -Level FATAL
            throw "[ClauseOS] Error: Missing required version definition for '$ToolKey' in $Manifest"
        }

        Write-ClauseLog "Executing recipe '$($Recipe.Name)' for '$ToolKey' ($Version)..." -Level DEBUG

        # Execute recipe passing Version and ProjectRoot
        & $Recipe.FullName -Version $Version -ProjectRoot $ProjectRoot
    }
} else {
    Write-ClauseLog "Installer directory not found at: $InstallerDir" -Level WARN
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
$MiseNu  = $env:CLAUSE_MISE_NU
$ExeExt  = if ($IsOSWindows) { ".exe" } else { "" }
$MiseBin = Join-Path $LocalBin "mise$ExeExt"
$NuBin   = Join-Path $LocalBin "nu$ExeExt"

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
Write-ClauseLog "Finalizing ClauseOS toolchain installation (MISE_ENV=$($env:MISE_ENV))..." -Level INFO
& $MiseBin install --yes
if ($LASTEXITCODE -ne 0) {
    Write-ClauseLog "Mise installation failed with exit code $LASTEXITCODE" -Level FATAL
    exit $LASTEXITCODE
}

# Bootstrap POSIX system packages (Lima via Mise brew manager)
if (-not $IsOSWindows) {
    $BrewLimaBin = if ($env:HOMEBREW_PREFIX) { Join-Path $env:HOMEBREW_PREFIX "bin/limactl" } else { $null }
    $HasLima = ($BrewLimaBin -and (Test-Path $BrewLimaBin)) -or (Get-Command "limactl" -ErrorAction SilentlyContinue)

    if (-not $HasLima) {
        Write-ClauseLog "Lima not detected; bootstrapping via Mise brew package manager..." -Level INFO
        & $MiseBin bootstrap packages apply --manager brew
        if ($LASTEXITCODE -ne 0) {
            Write-ClauseLog "Mise brew package bootstrap failed with exit code $LASTEXITCODE" -Level FATAL
            exit $LASTEXITCODE
        }
    }
}

# --- Direct Filesystem Probe for Plugin Engine Directories ---
# Custom [plugins] repos are cloned on the first `mise install` pass on Windows;
# dynamically discover active [plugins] keys so a second pass completes their tool installs.
$ActiveManifests = [System.Collections.Generic.List[string]]::new()
$ActiveManifests.Add((Join-Path $ProjectRoot ".mise.toml"))
if (-not [string]::IsNullOrWhiteSpace($env:MISE_ENV)) {
    foreach ($EnvName in ($env:MISE_ENV -split ',')) {
        $Trimmed = $EnvName.Trim()
        if ($Trimmed) {
            $ActiveManifests.Add((Join-Path $ProjectRoot ".mise.$Trimmed.toml"))
            $ActiveManifests.Add((Join-Path $ProjectRoot ".mise.$Trimmed.local.toml"))
        }
    }
}
$ActiveManifests.Add((Join-Path $ProjectRoot ".mise.local.toml"))

$DiscoveredPlugins = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$HasAnyManifest    = $false
foreach ($ManifestPath in $ActiveManifests) {
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { continue }
    $HasAnyManifest   = $true
    $InPluginsSection = $false
    foreach ($RawLine in [System.IO.File]::ReadAllLines($ManifestPath)) {
        $Line = $RawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith('#')) { continue }
        if ($Line -match '^\[([a-zA-Z0-9_.-]+)\]$') {
            $InPluginsSection = ($Matches[1] -eq 'plugins')
            continue
        }
        if ($InPluginsSection -and $Line.IndexOf('=') -gt 0) {
            $PluginKey = $Line.Substring(0, $Line.IndexOf('=')).Trim().Trim('"', "'")
            if (-not [string]::IsNullOrWhiteSpace($PluginKey)) {
                [void]$DiscoveredPlugins.Add($PluginKey)
            }
        }
    }
}

$RequiredTools = if ($HasAnyManifest) {
    @($DiscoveredPlugins)
} else {
    ($env:CLAUSE_REQUIRED_ENGINES -split '\s+') | Where-Object { $_ }
}
$MissingTools  = @()

$MiseInstallsBase = $env:MISE_INSTALLS_DIR

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

$EnvNu    = $env:CLAUSE_BOOT_NU
$ConfigNu = $env:CLAUSE_CONFIG_NU
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