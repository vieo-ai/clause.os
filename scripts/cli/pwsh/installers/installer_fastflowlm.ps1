param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

if ($IsOSMac) { return }

$InferenceNpuDir = Join-Path $env:CLAUSE_APPS_DIR "fastflowlm"
$FastFlowCheck   = Get-ChildItem -Path $InferenceNpuDir -ErrorAction SilentlyContinue
if ($FastFlowCheck) { return }

$FastFlowTag   = if ($Version.StartsWith("v")) { $Version } else { "v$Version" }
$FastFlowClean = $FastFlowTag.TrimStart("v")

Write-ClauseLog "Seeding FastFlowLM NPU Engine (${FastFlowTag})..." -Level INFO
$FastFlowAsset = if ($IsOSWindows) { "fastflowlm_${FastFlowClean}_windows_amd64.zip" } else { "fastflowlm_${FastFlowClean}_linux.tar.gz" }
$ArchivePath   = Join-Path $env:CLAUSE_TEMP_DIR $FastFlowAsset
Get-File -Url "https://github.com/ROCm/FastFlowLM/releases/download/${FastFlowTag}/${FastFlowAsset}" -OutFile $ArchivePath

$ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "fastflow_out"
Expand-HermeticArchive -ArchivePath $ArchivePath -DestinationPath $ExtractTarget
Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $InferenceNpuDir