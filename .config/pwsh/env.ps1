# .config/pwsh/env.ps1 - ClauseOS PowerShell Subshell Lock
$ErrorActionPreference = 'Stop'

$ClauseRoot              = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$env:CLAUSE_PROJECT_ROOT = $ClauseRoot
$env:HOME                = $ClauseRoot
$env:USERPROFILE         = $ClauseRoot

# XDG Base Directories
$env:XDG_CONFIG_HOME = Join-Path $ClauseRoot ".config"
$env:XDG_DATA_HOME   = Join-Path $ClauseRoot ".local\share"
$env:XDG_STATE_HOME  = Join-Path $ClauseRoot ".local\state"
$env:XDG_CACHE_HOME  = Join-Path $ClauseRoot ".cache"

# Windows Compatibility Environment Variables
$env:APPDATA      = Join-Path $ClauseRoot ".local\appdata"
$env:LOCALAPPDATA = Join-Path $ClauseRoot ".local\share"

# Application Profile Targets
$env:GIT_CONFIG_GLOBAL = Join-Path $ClauseRoot ".config\git\config"
$env:NU_CONFIG_DIR     = Join-Path $ClauseRoot ".config\nushell"
$env:GH_CONFIG_DIR     = Join-Path $ClauseRoot ".config\gh"

# Isolated Toolchain Directories
$env:MISE_DATA_DIR   = Join-Path $ClauseRoot ".cache\toolchain\mise"
$env:MISE_CONFIG_DIR = Join-Path $ClauseRoot ".cache\toolchain\mise-config"
$env:MISE_STATE_DIR  = Join-Path $ClauseRoot ".cache\toolchain\mise-state"
$env:MISE_CACHE_DIR  = Join-Path $ClauseRoot ".cache\toolchain\mise-cache"

# Enforce .local\bin Prepend
$LocalBin = Join-Path $ClauseRoot ".local\bin"
if ($env:PATH -notlike "*$LocalBin*") {
    $env:PATH = "${LocalBin};${env:PATH}"
}