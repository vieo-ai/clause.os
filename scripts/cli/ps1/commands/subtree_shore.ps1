# Requires PowerShell 7 or higher
#Requires -Version 7.0

[CmdletBinding()]
param (
    [string]$RemoteUrl     = "git@github.com:bgwdotdev/shore.git",
    [string]$Prefix        = "references/shore",
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
    # If 'main' doesn't exist on older repos, attempt fallback to 'master'
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
$isTracked = $false

if ($prefixExists) {
    $trackedFiles = git ls-files -- $Prefix
    if ($trackedFiles) {
        $isTracked = $true
    }
}

if (-not $isTracked) {
    # Build commit message for initial add
    $msg = if ($CommitMessage) {
        "$CommitMessage (upstream commit: $upstreamHash)"
    } else {
        "🌱 add: $Prefix subtree from $RemoteUrl @ $upstreamHash"
    }

    Write-Host "Subtree prefix '$Prefix' not detected in Git. Adding subtree..." -ForegroundColor Cyan
    git subtree add --prefix=$Prefix $RemoteUrl $Branch --squash -m $msg

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully added subtree at '$Prefix' (commit: $upstreamHash)." -ForegroundColor Green
    } else {
        Write-Error "Failed to add git subtree."
    }
} else {
    # Build commit message for pull update
    $msg = if ($CommitMessage) {
        "$CommitMessage (upstream commit: $upstreamHash)"
    } else {
        "🌱 update: $Prefix subtree from $RemoteUrl @ $upstreamHash"
    }

    Write-Host "Subtree prefix '$Prefix' found. Pulling latest updates from upstream..." -ForegroundColor Cyan
    git subtree pull --prefix=$Prefix $RemoteUrl $Branch --squash -m $msg

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully updated subtree at '$Prefix' (commit: $upstreamHash)." -ForegroundColor Green
    } else {
        Write-Error "Failed to pull updates for git subtree."
    }
}