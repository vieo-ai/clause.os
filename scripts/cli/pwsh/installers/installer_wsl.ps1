[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'

# Only applicable on Windows hosts
if (-not $IsOSWindows) { return }

$CleanVersion = $Version.TrimStart('v')

$WslCmd = Get-Command "wsl.exe" -ErrorAction SilentlyContinue
if (-not $WslCmd) {
    Write-ClauseLog "wsl.exe not found on this Windows host; skipping WSL setup." -Level WARN
    return
}

function Get-InstalledWslInfo {
    param([string]$WslExe)

    $null = & $WslExe --status 2>&1
    $IsEnabled = ($LASTEXITCODE -eq 0)

    $VerOut = (& $WslExe --version 2>&1 | Out-String) -replace "`0", ""
    $InstalledVer = $null
    if ($LASTEXITCODE -eq 0 -and $VerOut -match 'WSL[^0-9]*([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)') {
        $InstalledVer = $Matches[1]
    }

    return [PSCustomObject]@{
        Enabled = $IsEnabled
        Version = $InstalledVer
    }
}

function Test-WslVersionMatch {
    param(
        [string]$Installed,
        [string]$Target
    )
    if ([string]::IsNullOrWhiteSpace($Installed)) { return $false }
    return ($Installed -eq $Target) -or ($Installed.StartsWith("$Target."))
}

# 1. Fast-path check before any network calls: already enabled and at pinned version
$Current = Get-InstalledWslInfo -WslExe $WslCmd.Source
if ($Current.Enabled -and (Test-WslVersionMatch -Installed $Current.Version -Target $CleanVersion)) {
    return
}

# 2. Validate pinned version against microsoft/WSL GitHub Releases
$ReleaseUrl = "https://api.github.com/repos/microsoft/WSL/releases/tags/$CleanVersion"
$Headers = @{
    "Accept"     = "application/vnd.github+json"
    "User-Agent" = "ClauseOS-Bootloader"
}
$Token = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { $null }
if ($Token) {
    $Headers["Authorization"] = "Bearer $Token"
}

try {
    $Release = Invoke-RestMethod -Uri $ReleaseUrl -Headers $Headers -Method Get -TimeoutSec 15
    if ($Release -and $Release.tag_name) {
        Write-ClauseLog "Verified WSL release v$CleanVersion on GitHub (microsoft/WSL)." -Level INFO
    }
} catch {
    $StatusCode = $null
    if ($_.Exception.Response) {
        $StatusCode = [int]$_.Exception.Response.StatusCode
    }
    if ($StatusCode -eq 404) {
        Write-ClauseLog "Pinned WSL version '$CleanVersion' does not exist in microsoft/WSL GitHub releases." -Level ERROR
        throw "[ClauseOS ERROR] Invalid WSL version pin: $CleanVersion"
    }
    Write-ClauseLog "Could not query GitHub releases for WSL v$CleanVersion (offline or rate-limited); proceeding with local state check." -Level WARN
}

# 3. Elevation gate before enabling OS features or updating WSL
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {
    $StateMsg = if (-not $Current.Enabled) { "WSL is not enabled" } else { "WSL is at $($Current.Version) (pinned: $CleanVersion)" }
    Write-ClauseLog "$StateMsg. Run 'wsl --install --no-distribution' and 'wsl --update' from an elevated (Administrator) terminal." -Level WARN
    return
}

# 4. Enable Windows WSL features if not yet enabled
if (-not $Current.Enabled) {
    Write-ClauseLog "Enabling Windows Subsystem for Linux & Virtual Machine Platform features..." -Level INFO
    & dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
    & dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
}

# 5. Update WSL runtime if not at pinned version
$PostEnable = Get-InstalledWslInfo -WslExe $WslCmd.Source
if (-not (Test-WslVersionMatch -Installed $PostEnable.Version -Target $CleanVersion)) {
    $CurVerLabel = if ($PostEnable.Version) { $PostEnable.Version } else { "none" }
    Write-ClauseLog "Updating WSL runtime (current: $CurVerLabel, target: $CleanVersion)..." -Level INFO
    & $WslCmd.Source --update
    if ($LASTEXITCODE -ne 0) {
        Write-ClauseLog "wsl --update exited with code $LASTEXITCODE (a system reboot may be required to finish activating VirtualMachinePlatform)." -Level WARN
        return
    }
}

# 6. Final Verification
$Verified = Get-InstalledWslInfo -WslExe $WslCmd.Source
if (-not $Verified.Enabled) {
    Write-ClauseLog "WSL features enabled, but WSL is not active yet - a Windows reboot is required." -Level WARN
    return
}

if (Test-WslVersionMatch -Installed $Verified.Version -Target $CleanVersion) {
    Write-ClauseLog "WSL verified enabled at pinned version $($Verified.Version)." -Level INFO
} else {
    Write-ClauseLog "WSL enabled at version $($Verified.Version) (pinned target in .clause.toml is $CleanVersion)." -Level WARN
}