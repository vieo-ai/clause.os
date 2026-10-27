#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne$Expected) {
        Write-Host " [FAIL] $Message" -ForegroundColor Red
        Write-Host "        Expected: $Expected"
        Write-Host "        Actual:   $Actual"
        exit 1
    }
    Write-Host " [PASS] $Message" -ForegroundColor Green
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        Write-Host " [FAIL] $Message" -ForegroundColor Red
        exit 1
    }
    Write-Host " [PASS] $Message" -ForegroundColor Green
}

$TestScript = {
    $TestDir = "$PSScriptRoot"
    $ProjectRoot = Resolve-Path (Join-Path$TestDir "..\..")
    $EnvScript = Join-Path$ProjectRoot "scripts/cli/pwsh/config/env.ps1"

    if (-not (Test-Path $EnvScript)) {
        Write-Host " [FAIL] Canonical env script not found at $EnvScript" -ForegroundColor Red
        exit 1
    }

    . $EnvScript

    $ExpectedHome = Join-Path$ProjectRoot ".home"

    Assert-Equal $env:CLAUSE_PROJECT_ROOT$ProjectRoot "Project root matches"
    Assert-Equal $env:HOME$ExpectedHome "HOME confined to .home"
    Assert-Equal $env:USERPROFILE$ExpectedHome "USERPROFILE confined to .home"

    if ($IsWindows -or$env:OS -eq "Windows_NT") {
        Assert-Equal $env:LOCALAPPDATA (Join-Path$ExpectedHome "AppData\Local") "Windows LOCALAPPDATA location"
        Assert-Equal $env:APPDATA (Join-Path$ExpectedHome "AppData\Roaming") "Windows APPDATA location"
        Assert-True (-not $env:XDG_CONFIG_HOME) "Windows omits global XDG_CONFIG_HOME"
    } else {
        Assert-Equal $env:XDG_CONFIG_HOME (Join-Path$ExpectedHome ".config") "POSIX XDG_CONFIG_HOME set"
        Assert-Equal $env:XDG_DATA_HOME (Join-Path$ExpectedHome ".local/share") "POSIX XDG_DATA_HOME set"
    }

    Assert-True ($env:PATH.StartsWith($env:CLAUSE_BIN_DIR)) "CLAUSE_BIN_DIR is first in PATH"
    Assert-True ($env:PATH -notlike "*mise*shims*") "Mise shims are not injected into PATH"
}

powershell -NoProfile -Command $TestScript