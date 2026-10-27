param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

$LocalBin = $env:CLAUSE_BIN_DIR
$ExeExt   = if ($IsOSWindows) { ".exe" } else { "" }
$NuBin    = Join-Path $LocalBin "nu$ExeExt"

if (Test-Path $NuBin) { return }

Write-ClauseLog "Pre-seeding Nushell (v${Version}) into $LocalBin..." -Level INFO
$NuAsset = if ($IsOSWindows) { "nu-${Version}-x86_64-pc-windows-msvc.zip" } elseif ($IsOSMac) { "nu-${Version}-x86_64-apple-darwin.tar.gz" } else { "nu-${Version}-x86_64-unknown-linux-gnu.tar.gz" }
$ArchivePath = Join-Path $env:CLAUSE_TEMP_DIR $NuAsset
Get-File -Url "https://github.com/nushell/nushell/releases/download/${Version}/$NuAsset" -OutFile $ArchivePath

$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "nu_out"
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $LocalBin
Set-PosixExecutable -FilePath $NuBin