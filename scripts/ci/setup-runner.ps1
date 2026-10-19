param (
    [Parameter(Mandatory=$false)]
    [string]$RunnerToken,
    [Parameter(Mandatory=$false)]
    [string]$RepoUrl
)

# scripts/ci/setup-runner.ps1
# Persistent Self-Hosted Runner Provisioner for Windows PowerShell 5.1+
$ErrorActionPreference = "Stop"

$ProjectRoot = if ($env:CLAUSE_PROJECT_ROOT) { $env:CLAUSE_PROJECT_ROOT } else { Get-Location }
$RunnerDir   = Join-Path $ProjectRoot ".cache\ci\runner"
$TmpDir      = Join-Path $ProjectRoot ".cache\tmp_bootstrap"

if (-not (Test-Path $RunnerDir)) {
    New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
}
if (-not (Test-Path $TmpDir)) {
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
}

$RunnerVersion = "2.337.0"
$RunnerAsset   = "actions-runner-win-x64-${RunnerVersion}.zip"
$RunnerUrl     = "https://github.com/actions/runner/releases/download/v${RunnerVersion}/${RunnerAsset}"
$ZipPath       = Join-Path $TmpDir $RunnerAsset

# Download via native curl.exe or fallback
if (-not (Test-Path (Join-Path $RunnerDir "config.cmd"))) {
    Write-Host "[ClauseOS CI] Downloading GitHub Actions Runner (v${RunnerVersion})..." -ForegroundColor Cyan
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        curl.exe -sSL "$RunnerUrl" -o "$ZipPath"
        if ($LASTEXITCODE -ne 0) { throw "[ClauseOS CI] Download failed via curl.exe" }
    } else {
        Invoke-WebRequest -Uri $RunnerUrl -OutFile $ZipPath -UseBasicParsing
    }

    Write-Host "[ClauseOS CI] Extracting runner..." -ForegroundColor Cyan
    if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
        tar.exe -xf "$ZipPath" -C "$RunnerDir"
        if ($LASTEXITCODE -ne 0) { throw "[ClauseOS CI] Extraction failed via tar.exe" }
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $RunnerDir)
    }
}

Set-Location $RunnerDir

# Initial Registration Guard
if (-not (Test-Path (Join-Path $RunnerDir ".runner"))) {
    if (-not $RepoUrl) { $RepoUrl = Read-Host "Enter GitHub Repository URL" }
    if (-not $RunnerToken) { $RunnerToken = Read-Host "Enter GitHub Runner Registration Token" }

    Write-Host "[ClauseOS CI] Registering runner agent with GitHub..." -ForegroundColor Cyan
    & .\config.cmd --url $RepoUrl --token $RunnerToken --labels windows,x64 --unattended --replace
    if ($LASTEXITCODE -ne 0) {
        throw "[ClauseOS CI] Error: Registration failed. Ensure your runner token is fresh and valid."
    }
} else {
    Write-Host "[ClauseOS CI] Existing registration found. Reconnecting to GitHub..." -ForegroundColor Green
}

Write-Host "[ClauseOS CI] Runner listening for jobs. Press Ctrl+C to stop..." -ForegroundColor Green
.\run.cmd