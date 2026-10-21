# clause.ps1 - Native PowerShell Entry Point for ClauseOS Bootloader
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Direct path to the microkernel bootloader
$ClauseBootloader = Join-Path $ScriptDir "boot.ps1"

if (-not (Test-Path $ClauseBootloader)) {
    Write-Host "[ClauseOS] Critical Error: Bootloader script not found at $ClauseBootloader" -ForegroundColor Red
    exit 1
}

# Execute clause.ps1 with un-restricted policy for the child process session
if ($ScriptArgs) {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ClauseBootloader @ScriptArgs
} else {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ClauseBootloader
}

exit $LASTEXITCODE