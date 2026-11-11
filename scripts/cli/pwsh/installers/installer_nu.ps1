[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'

$LocalBin = $env:CLAUSE_BIN_DIR
$ExeExt   = if ($IsOSWindows) { ".exe" } else { "" }
$NuBin    = Join-Path $LocalBin "nu$ExeExt"

if (Test-Path $NuBin) { return }

$CleanNuVer = $Version.TrimStart('v')
Write-ClauseLog "Pre-seeding Nushell (v${CleanNuVer}) into $LocalBin..." -Level INFO

$NuAsset = if ($IsOSWindows) {
    "nu-${CleanNuVer}-x86_64-pc-windows-msvc.zip"
} elseif ($IsOSMac) {
    "nu-${CleanNuVer}-x86_64-apple-darwin.tar.gz"
} else {
    "nu-${CleanNuVer}-x86_64-unknown-linux-musl.tar.gz"
}

$ArchivePath = Join-Path $env:CLAUSE_TEMP_DIR $NuAsset
Get-File -Url "https://github.com/nushell/nushell/releases/download/${CleanNuVer}/$NuAsset" -OutFile $ArchivePath

$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "nu_extracted"
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget

# Locate extracted binary and move to hermetic bin
$ExtractedNu = Get-ChildItem -Path $ExtractTarget -Filter "nu$ExeExt" -Recurse | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1
if (-not $ExtractedNu) {
    Write-ClauseLog "Failed to locate extracted nu binary in $ExtractTarget" -Level FATAL
    throw "[ClauseOS] Error: Could not find nu executable in extracted archive"
}

Move-Item -Path $ExtractedNu.FullName -Destination $NuBin -Force
Set-PosixExecutable -FilePath $NuBin