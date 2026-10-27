param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

$LocalBin = $env:CLAUSE_BIN_DIR
$ExeExt   = if ($IsOSWindows) { ".exe" } else { "" }
$JustBin  = Join-Path $LocalBin "just$ExeExt"

if (Test-Path $JustBin) { return }

Write-ClauseLog "Pre-seeding Just (v${Version}) into $LocalBin..." -Level INFO
$JustAsset = if ($IsOSWindows) { "just-${Version}-x86_64-pc-windows-msvc.zip" } elseif ($IsOSMac) { "just-${Version}-x86_64-apple-darwin.tar.gz" } else { "just-${Version}-x86_64-unknown-linux-musl.tar.gz" }
$ArchivePath = Join-Path $env:CLAUSE_TEMP_DIR $JustAsset
Get-File -Url "https://github.com/casey/just/releases/download/${Version}/$JustAsset" -OutFile $ArchivePath

$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "just_out"
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $LocalBin
Set-PosixExecutable -FilePath $JustBin