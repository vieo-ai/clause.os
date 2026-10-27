param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

$LocalBin = $env:CLAUSE_BIN_DIR
$ExeExt   = if ($IsOSWindows) { ".exe" } else { "" }
$MiseBin  = Join-Path $LocalBin "mise$ExeExt"

if (Test-Path $MiseBin) { return }

Write-ClauseLog "Pre-seeding Mise (v${Version}) into $LocalBin..." -Level INFO
$MiseAsset = if ($IsOSWindows) { "mise-v${Version}-windows-x64.zip" } elseif ($IsOSMac) { "mise-v${Version}-macos-x64.tar.gz" } else { "mise-v${Version}-linux-x64.tar.gz" }
$ArchivePath = Join-Path $env:CLAUSE_TEMP_DIR $MiseAsset
Get-File -Url "https://github.com/jdx/mise/releases/download/v${Version}/$MiseAsset" -OutFile $ArchivePath

$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "mise_out"
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget

$FoundMiseExe = Get-ChildItem -Path $ExtractTarget -Filter "mise$ExeExt" -Recurse | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1

if ($FoundMiseExe) {
    Get-ChildItem -Path $FoundMiseExe.DirectoryName | Move-Item -Destination $LocalBin -Force
    Set-PosixExecutable -FilePath $MiseBin

    if (-not $IsOSWindows) {
        $MiseParent = $FoundMiseExe.Directory.Parent
        if ($MiseParent -and (Test-Path $MiseParent.FullName) -and ($MiseParent.FullName -ne $ExtractTarget)) {
            Get-ChildItem -Path $MiseParent.FullName | Where-Object { $_.Name -ne "bin" } | ForEach-Object {
                $DestDir = Join-Path $env:CLAUSE_HOME ".local/$($_.Name)"
                if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Force -Path $DestDir | Out-Null }
                Get-ChildItem -Path $_.FullName | Move-Item -Destination $DestDir -Force
            }
        }
    }
} else {
    Write-ClauseLog "Mise executable ($MiseBin) could not be located in extracted archive" -Level ERROR
    throw "[ClauseOS ERROR] Mise binary missing in $ExtractTarget"
}