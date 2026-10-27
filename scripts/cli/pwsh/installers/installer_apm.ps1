param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

$ApmDir = Join-Path $env:CLAUSE_APPS_DIR "apm"
$ExeExt = if ($IsOSWindows) { ".exe" } else { "" }
$ApmBin = Join-Path $ApmDir "apm$ExeExt"

if (Test-Path $ApmBin) { return }

$ApmTag = if ($Version.StartsWith("v")) { $Version } else { "v$Version" }

Write-ClauseLog "Seeding Agent Package Manager (${ApmTag})..." -Level INFO
$ApmAsset = if ($IsOSWindows) { "apm-windows-x86_64.zip" } elseif ($IsOSMac) { "apm-darwin-x86_64.tar.gz" } else { "apm-linux-x86_64.tar.gz" }
$ArchivePath = Join-Path $env:CLAUSE_TEMP_DIR $ApmAsset
Get-File -Url "https://github.com/microsoft/apm/releases/download/${ApmTag}/${ApmAsset}" -OutFile $ArchivePath

$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "apm_out"
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $ApmDir
Set-PosixExecutable -FilePath $ApmBin