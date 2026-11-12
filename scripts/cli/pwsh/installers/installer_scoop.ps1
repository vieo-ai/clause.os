[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'

# Only run on Windows NT
if (-not $IsOSWindows) { return }

$LocalBin     = $env:CLAUSE_BIN_DIR
$CacheDir     = if ($env:CLAUSE_CACHE_DIR) { $env:CLAUSE_CACHE_DIR } else { Join-Path $env:CLAUSE_HOME ".cache" }
$ToolchainDir = Join-Path $CacheDir "toolchain"
$ScoopDir     = Join-Path $ToolchainDir "scoop"
$ScoopShims   = Join-Path $ScoopDir "shims"
$ScoopCmd     = Join-Path $ScoopShims "scoop.ps1"

# Fast-path exit if already seeded and shim exists
if (Test-Path $ScoopCmd) { return }

# Pre-seed hermetic config/toolchain/scoop/config.json
$ScoopConfigDir = Join-Path $env:CLAUSE_HOME ".config\scoop"
if (-not (Test-Path $ScoopConfigDir)) {
    New-Item -ItemType Directory -Path $ScoopConfigDir -Force | Out-Null
}
$ScoopConfigFile = Join-Path $ScoopConfigDir "config.json"

if (-not (Test-Path $ScoopConfigFile)) {
    @{
        create_startmenu_shortcut = $false
        show_update_log           = $false
    } | ConvertTo-Json | Set-Content -Path $ScoopConfigFile -Encoding UTF8
}

# Clean up host registry PATH leaks matching Scoop shims
$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($UserPath -like "*$ScoopShims*") {
    $CleanedPath = ($UserPath -split ';' | Where-Object { $_ -and $_ -ne $ScoopShims }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $CleanedPath, 'User')
}

# Clean up host Start Menu shortcut leaks
$ScoopStartMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps"
if (Test-Path $ScoopStartMenu) {
    Remove-Item -Path $ScoopStartMenu -Recurse -Force -ErrorAction SilentlyContinue
}

Write-ClauseLog "Pre-seeding Hermetic Scoop into $ScoopDir..." -Level INFO
$Installer = Join-Path $env:CLAUSE_TEMP_DIR "install_scoop.ps1"

try {
    Get-File -Url 'https://get.scoop.sh' -OutFile $Installer
    & $Installer -ScoopDir "$ScoopDir" -NoPath
    Write-ClauseLog "Scoop pre-seeded successfully." -Level INFO
} catch {
    Write-ClauseLog "Failed to install Scoop: $_" -Level FATAL
    throw "[ClauseOS Stage 2] Error: Failed to install Scoop: $_"
} finally {
    if (Test-Path $Installer) { Remove-Item $Installer -Force -ErrorAction SilentlyContinue }
}

# Ensure Scoop shims and binaries are accessible inside CLAUSE_BIN_DIR
$ScoopBinTarget = Join-Path $LocalBin "scoop.cmd"
if (-not (Test-Path $ScoopBinTarget)) {
    # Generate wrapper CMD in $LocalBin delegating to the hermetic scoop.ps1
    Set-Content -Path $ScoopBinTarget -Value @"
@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$ScoopCmd" %*
"@ -Encoding ASCII
}