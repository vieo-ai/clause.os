param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

$CodeDir   = Join-Path $env:CLAUSE_APPS_DIR "vscode"
$CodeCheck = Get-ChildItem -Path $CodeDir -ErrorAction SilentlyContinue
if ($CodeCheck) { return }

Write-ClauseLog "Seeding VS Code Portable Engine (v${Version})..." -Level INFO
$CodeAsset = if ($IsOSWindows) { "vscode-win32-x64-${Version}.zip" } elseif ($IsOSMac) { "VSCode-darwin-universal.zip" } else { "vscode-linux-x64-${Version}.tar.gz" }
$CodeUrl   = if ($IsOSWindows) { "https://update.code.visualstudio.com/${Version}/win32-x64-archive/stable" } elseif ($IsOSMac) { "https://update.code.visualstudio.com/${Version}/darwin-universal/stable" } else { "https://update.code.visualstudio.com/${Version}/linux-x64/stable" }

$ArchivePath = Join-Path $env:CLAUSE_TEMP_DIR $CodeAsset
Get-File -Url $CodeUrl -OutFile $ArchivePath

$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "code_out"
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $CodeDir
New-Item -ItemType Directory -Path (Join-Path $CodeDir "data") -Force | Out-Null