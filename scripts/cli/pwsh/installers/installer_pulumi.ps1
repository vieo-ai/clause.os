param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

$TargetDir = Join-Path $env:CLAUSE_APPS_DIR "pulumi"
$ExeExt    = if ($IsOSWindows) { ".exe" } else { "" }
$PulumiBin = Join-Path $TargetDir "pulumi$ExeExt"

# Fast-path check: Return immediately if already installed
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

$ArchivePath   = Join-Path $env:CLAUSE_TEMP_DIR $Asset
$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "pulumi_out"

Write-ClauseLog "Seeding Pulumi Infrastructure as Code Engine (${Tag})..." -Level INFO
Get-File -Url "https://github.com/pulumi/pulumi/releases/download/${Tag}/${Asset}" -OutFile $ArchivePath
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget

# If re-seeding or fixing a dirty state, clear previous folder
if (Test-Path $TargetDir) {
    Remove-Item -Path $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
}

Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $TargetDir

# Windows packaging puts binaries in a nested `bin` folder; hoist them to $TargetDir root
$NestedBinDir = Join-Path $TargetDir "bin"
if (Test-Path $NestedBinDir) {
    Get-ChildItem -Path $NestedBinDir -Force | Move-Item -Destination $TargetDir -Force
    Remove-Item -Path $NestedBinDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Ensure POSIX executables have +x permissions
if (-not $IsOSWindows) {
    Get-ChildItem -Path $TargetDir -File | ForEach-Object {
        Set-PosixExecutable -FilePath $_.FullName
    }
}