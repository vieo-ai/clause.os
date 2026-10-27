#!/usr/bin/env pwsh
# tests/env/run_tests.ps1 - OS Detection & Test Orchestrator
$ErrorActionPreference = 'Stop'

$IsOSWindows = $IsWindows -or $env:OS -eq "Windows_NT"
$TestDir = $PSScriptRoot

Write-Host "=== Running ClauseOS Environment Invariant Tests ===" -ForegroundColor Cyan

# 1. PowerShell Test (always runs on Windows, runs on Mac/Linux if pwsh exists)
Write-Host "`n[TEST] PowerShell Environment (env.ps1)..." -ForegroundColor Yellow
& (Join-Path $TestDir "test_env.ps1")

# 2. Nushell Test (if nu executable is found)
Write-Host "`n[TEST] Nushell Environment (env.nu)..." -ForegroundColor Yellow
$NuCmd = Get-Command nu -ErrorAction SilentlyContinue
if ($NuCmd) {
    & $NuCmd.Source (Join-Path $TestDir "test_env.nu")
} else {
    Write-Host " [WARN] Nushell binary not on PATH; skipping nu contract test." -ForegroundColor DarkYellow
}

# 3. POSIX Test (Linux / macOS only)
if (-not $IsOSWindows) {
    Write-Host "`n[TEST] POSIX Shell Environment (env.sh)..." -ForegroundColor Yellow
    & sh (Join-Path $TestDir "test_env.sh")
}

Write-Host "`nAll platform environment tests completed successfully!" -ForegroundColor Green