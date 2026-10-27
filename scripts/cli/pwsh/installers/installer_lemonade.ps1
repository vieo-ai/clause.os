param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

$InferenceGpuDir = Join-Path $env:CLAUSE_APPS_DIR "lemonade"
$LemonadeCheck   = Get-ChildItem -Path $InferenceGpuDir -ErrorAction SilentlyContinue
if ($LemonadeCheck) { return }

$LemonadeTag   = if ($Version.StartsWith("v")) { $Version } else { "v$Version" }
$LemonadeClean = $LemonadeTag.TrimStart("v")

Write-ClauseLog "Seeding Lemonade GPU Engine (${LemonadeTag})..." -Level INFO
$LemonadeAsset = if ($IsOSWindows) { "lemonade-embeddable-${LemonadeClean}-windows-x64.zip" } elseif ($IsOSMac) { "lemonade-embeddable-${LemonadeClean}-macos-arm64.tar.gz" } else { "lemonade-embeddable-${LemonadeClean}-ubuntu-x64.tar.gz" }
$ArchivePath   = Join-Path $env:CLAUSE_TEMP_DIR $LemonadeAsset
Get-File -Url "https://github.com/lemonade-sdk/lemonade/releases/download/${LemonadeTag}/${LemonadeAsset}" -OutFile $ArchivePath

$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "lemonade_out"
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $InferenceGpuDir