# scripts/cli/pwsh/installers/installer_pulumi.ps1
param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

$TargetDir = Join-Path $env:CLAUSE_APPS_DIR "pulumi"
$ExeExt    = if ($IsOSWindows) { ".exe" } else { "" }
# Pulumi places binaries inside bin/
$PulumiBin = Join-Path $TargetDir "bin" "pulumi$ExeExt"

if (Test-Path $PulumiBin) { return }

$Tag   = if ($Version.StartsWith("v")) { $Version } else { "v$Version" }
$Clean = $Tag.TrimStart("v")

# Resolve platform archive
$Asset = if ($IsOSWindows) {
    "pulumi-v${Clean}-windows-x64.zip"
} elseif ($IsOSMac) {
    $MacArch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or (uname -m 2>$null) -eq "arm64") { "arm64" } else { "x64" }
    "pulumi-v${Clean}-darwin-${MacArch}.tar.gz"
} else {
    "pulumi-v${Clean}-linux-x64.tar.gz"
}

$ArchivePath = Join-Path $env:CLAUSE_TEMP_DIR $Asset
$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "pulumi_out"

Write-ClauseLog "Seeding Pulumi Infrastructure as Code Engine (${Tag})..." -Level INFO
Get-File -Url "https://github.com/pulumi/pulumi/releases/download/${Tag}/${Asset}" -OutFile $ArchivePath
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget

# Clean up stale partial target if it exists prior to moving
if (Test-Path $TargetDir) {
    Remove-Item -Path $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
}

Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $TargetDir

# Ensure POSIX executables have +x permissions
if (-not $IsOSWindows) {
    Get-ChildItem -Path (Join-Path $TargetDir "bin") -File | ForEach-Object {
        Set-PosixExecutable -FilePath $_.FullName
    }
}