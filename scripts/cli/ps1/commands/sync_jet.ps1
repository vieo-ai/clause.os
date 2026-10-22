# Requires PowerShell 7 or higher
#Requires -Version 7.0

[CmdletBinding()]
param (
    [string]$RemoteUrl     = "git@github.com:i2y/jet.git",
    [string]$Prefix        = "packages/carrier_jet",
    [string]$Branch        = "main",
    [string]$CommitMessage = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure we are inside a Git repository
$gitCheck = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Current directory is not a Git repository. Please run this script from inside your repository root."
    exit 1
}

# Determine the absolute repository root
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

# Fetch the short commit hash (7 characters) from the remote branch
Write-Host "Fetching latest commit hash from $RemoteUrl ($Branch)..." -ForegroundColor Cyan
$lsRemoteOutput = git ls-remote $RemoteUrl "refs/heads/$Branch" 2>$null

if (-not $lsRemoteOutput) {
    Write-Host "Branch '$Branch' not found. Checking 'master' branch..." -ForegroundColor Yellow
    $Branch = "master"
    $lsRemoteOutput = git ls-remote $RemoteUrl "refs/heads/$Branch" 2>$null
}

if (-not $lsRemoteOutput) {
    Write-Error "Unable to reach remote repository or find branch '$Branch'."
    exit 1
}

$upstreamHash = ($lsRemoteOutput -split '\s+')[0].Substring(0, 7)

# Check if the prefix directory exists and contains files tracked by Git
$prefixExists = Test-Path -Path $Prefix
$isTracked =$false

if ($prefixExists) {
    $trackedFiles = git ls-files --$Prefix
    if ($trackedFiles) {
        $isTracked =$true
    }
}

if (-not $isTracked) {
    $msg = if ($CommitMessage) {
        "$CommitMessage (upstream commit:$upstreamHash)"
    } else {
        "🌱 add: $Prefix subtree from $RemoteUrl @ $upstreamHash"
    }

    Write-Host "Subtree prefix '$Prefix' not detected in Git. Adding subtree..." -ForegroundColor Cyan
    git subtree add --prefix=$Prefix $RemoteUrl $Branch --squash -m$msg

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to add git subtree for $Prefix."
        exit 1
    }
} else {
    $msg = if ($CommitMessage) {
        "$CommitMessage (upstream commit:$upstreamHash)"
    } else {
        "🌱 update: $Prefix subtree from $RemoteUrl @ $upstreamHash"
    }

    Write-Host "Subtree prefix '$Prefix' found. Pulling latest updates from upstream..." -ForegroundColor Cyan
    git subtree pull --prefix=$Prefix $RemoteUrl $Branch --squash -m$msg

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to pull updates for git subtree $Prefix."
        exit 1
    }
}

# ==============================================================================
# POST-SYNC BUILD STEP: COMPILE 'jet' BINARY INTO .local/bin/
# ==============================================================================
Write-Host "`nBuilding 'jet' executable from packages/carrier_jet source..." -ForegroundColor Cyan

$jetDir = Join-Path $repoRoot $Prefix
$localBin = Join-Path $repoRoot ".local" "bin"

if (-not (Test-Path $localBin)) {
    New-Item -ItemType Directory -Path $localBin -Force | Out-Null
}

Push-Location $jetDir
try {
    Write-Host "  [1/3] Running gleam build..." -ForegroundColor Yellow
    mise exec -- gleam build

    Write-Host "  [2/3] Exporting Erlang shipment & compiling escript..." -ForegroundColor Yellow
    mise exec -- gleam export erlang-shipment
    mise exec -- escript build_escript.erl

    # Copy built jet binary straight to .local/bin/jet
    $jetCompiledBinary = Join-Path $jetDir "jet"
    if (Test-Path $jetCompiledBinary) {
        $targetBinary = Join-Path $localBin "jet.exe"
        if ($IsLinux -or $IsMacOS) {
            $targetBinary = Join-Path $localBin "jet"
        }
        
        Copy-Item -Path $jetCompiledBinary -Destination $targetBinary -Force
        Write-Host "  [3/3] Successfully installed binary to .local/bin/jet" -ForegroundColor Green
    } else {
        Write-Warning "Escript build completed but compiled binary 'jet' was not found in $jetDir."
    }
}
catch {
    Write-Error "Failed to compile jet: $_"
}
finally {
    Pop-Location
}

Write-Host "`n🚀 Jet sync & compilation complete! You can now type 'jet' directly in ClauseOS." -ForegroundColor Green