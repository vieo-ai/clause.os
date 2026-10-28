# scripts/cli/pwsh/config/env.ps1 - ClauseOS Canonical PowerShell Environment
$ErrorActionPreference = 'Stop'

# 1. Base Anchors
if (-not $env:CLAUSE_PROJECT_ROOT) {
    $env:CLAUSE_PROJECT_ROOT = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
}

$ProjectRoot     = $env:CLAUSE_PROJECT_ROOT
$ClauseHome      = Join-Path $ProjectRoot ".home"
$env:CLAUSE_HOME = $ClauseHome

# 2. Confinement Anchors
$env:HOME        = $ClauseHome
$env:USERPROFILE = $ClauseHome

# 3. Platform Hierarchy
$IsOSWindows = $IsWindows -or $env:OS -eq "Windows_NT"
$IsOSMac     = $IsMacOS -or ($PSVersionTable.OS -like "*Darwin*")
$IsOSLinux   = -not $IsOSWindows -and -not $IsOSMac

if ($IsOSWindows) {
    # Windows Native NT Layout inside .home
    $WinLocal   = Join-Path $ClauseHome "AppData\Local"
    $WinRoaming = Join-Path $ClauseHome "AppData\Roaming"

    $env:LOCALAPPDATA = $WinLocal
    $env:APPDATA      = $WinRoaming

    $env:CLAUSE_BIN_DIR   = Join-Path $WinLocal "Programs\bin"
    $env:CLAUSE_APPS_DIR  = Join-Path $WinLocal "Programs\apps"
    $env:CLAUSE_CACHE_DIR = Join-Path $WinLocal "cache"
    $env:CLAUSE_TEMP_DIR  = Join-Path $WinLocal "Temp"
    $env:CLAUSE_LOGS_DIR  = Join-Path $WinLocal "Programs\logs"

    # Mise paths on Windows
    $env:MISE_DATA_DIR   = Join-Path $WinLocal "mise"
    $env:MISE_CONFIG_DIR = Join-Path $WinRoaming "mise"
    $env:MISE_STATE_DIR  = Join-Path $WinLocal "mise\state"
    $env:MISE_CACHE_DIR  = Join-Path $WinLocal "mise\cache"
} else {
    # POSIX XDG Standards inside .home
    $env:XDG_CONFIG_HOME = Join-Path $ClauseHome ".config"
    $env:XDG_DATA_HOME   = Join-Path $ClauseHome ".local\share"
    $env:XDG_STATE_HOME  = Join-Path $ClauseHome ".local\state"
    $env:XDG_CACHE_HOME  = Join-Path $ClauseHome ".cache"

    $env:CLAUSE_BIN_DIR   = Join-Path $ClauseHome ".local\bin"
    $env:CLAUSE_APPS_DIR  = Join-Path $ClauseHome ".local\apps"
    $env:CLAUSE_CACHE_DIR = $env:XDG_CACHE_HOME
    $env:CLAUSE_TEMP_DIR  = Join-Path $env:XDG_CACHE_HOME "tmp_bootstrap"
    $env:CLAUSE_LOGS_DIR  = Join-Path $ClauseHome ".local\logs"

    # Mise paths on POSIX
    $env:MISE_DATA_DIR   = Join-Path $env:XDG_DATA_HOME "mise"
    $env:MISE_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME "mise"
    $env:MISE_STATE_DIR  = Join-Path $env:XDG_STATE_HOME "mise"
    $env:MISE_CACHE_DIR  = Join-Path $env:XDG_CACHE_HOME "mise"
}

# Ensure the root cache directory exists on disk
if (-not (Test-Path $env:CLAUSE_CACHE_DIR)) {
    New-Item -ItemType Directory -Force -Path $env:CLAUSE_CACHE_DIR | Out-Null
}

# 4. Identity & Tool Confining
$env:GIT_CONFIG_GLOBAL = Join-Path $ClauseHome ".gitconfig"
$env:GH_CONFIG_DIR     = if ($IsOSWindows) { Join-Path $env:APPDATA "GitHub CLI" } else { Join-Path $env:XDG_CONFIG_HOME "gh" }
$env:NU_CONFIG_DIR     = Join-Path $ProjectRoot "scripts\cli\nu\config"

# 5. Global PATH Management (Prepend Stage 0 Binaries Only)
if ($env:PATH -notlike "*$($env:CLAUSE_BIN_DIR)*") {
    $env:PATH = "$($env:CLAUSE_BIN_DIR);$env:PATH"
}