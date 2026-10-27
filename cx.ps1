# cx.ps1 - Native PowerShell Entry Point for ClauseOS Bootloader
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$ClauseBootloader = Join-Path $ScriptDir "boot.ps1"

if (-not (Test-Path $ClauseBootloader)) {
    Write-Host "[ClauseOS] Critical Error: Bootloader script not found at $ClauseBootloader" -ForegroundColor Red
    exit 1
}

# Delegate to the bootloader maintaining execution policy bypass
if ($ScriptArgs) {
    & $ClauseBootloader @ScriptArgs
} else {
    & $ClauseBootloader
}

exit $LASTEXITCODE