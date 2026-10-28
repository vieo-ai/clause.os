param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

# ==============================================================================
# 1. HERMETIC ROOTS & DIRECTORY MAPPING
# ==============================================================================
$TargetDir     = Join-Path $env:CLAUSE_APPS_DIR "comfyui"
$VenvDir       = Join-Path $TargetDir "venv"
$SourceDir     = Join-Path $TargetDir "src"
$PrivatePyDir  = Join-Path $TargetDir "python"
$ExeExt        = if ($IsOSWindows) { ".exe" } else { "" }
$ScriptDir     = if ($IsOSWindows) { "Scripts" } else { "bin" }
$PythonBin     = Join-Path $VenvDir "$ScriptDir\python$ExeExt"
$ShimDir       = Join-Path $TargetDir "bin"
$MainPy        = Join-Path $SourceDir "main.py"

# Fast-path idempotency check
if ((Test-Path $PythonBin) -and (Test-Path $MainPy) -and ((Test-Path (Join-Path $ShimDir "comfyui.bat")) -or (Test-Path (Join-Path $ShimDir "comfyui")))) {
    return
}

# Resolve uv
$UvExe = $null
$DirectUv = Join-Path $env:CLAUSE_BIN_DIR "uv$ExeExt"
if (Test-Path $DirectUv) {
    $UvExe = $DirectUv
} else {
    $CommandUv = Get-Command uv$ExeExt -ErrorAction SilentlyContinue
    if ($CommandUv) {
        $UvExe = $CommandUv.Source
    } else {
        $MiseShimRel = if ($IsOSWindows) { "AppData\Local\mise\shims\uv.exe" } else { ".local/share/mise/shims/uv" }
        $MiseShims   = Join-Path $env:CLAUSE_HOME $MiseShimRel
        if (Test-Path $MiseShims) { $UvExe = $MiseShims }
    }
}

if (-not $UvExe) {
    Write-ClauseLog "uv package manager missing. Ensure 'uv' is seeded via Mise." -Level FATAL
    throw "[ClauseOS] Missing prerequisite: uv"
}

Write-ClauseLog "Initializing Hermetic ComfyUI Studio Deployment ($Version)..." -Level INFO

# Provision directories
@($TargetDir, $ShimDir, $PrivatePyDir, $env:CLAUSE_TEMP_DIR, $env:CLAUSE_CACHE_DIR) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
}

$env:UV_CACHE_DIR          = Join-Path $env:CLAUSE_CACHE_DIR "uv"
$env:UV_PYTHON_INSTALL_DIR = $PrivatePyDir

if (-not (Test-Path $env:UV_CACHE_DIR)) {
    New-Item -ItemType Directory -Force -Path $env:UV_CACHE_DIR | Out-Null
}

# ==============================================================================
# 2. STAGE COMFYUI REPOSITORY
# ==============================================================================
if (-not (Test-Path $MainPy)) {
    Write-ClauseLog "Cloning ComfyUI source ($Version)..." -Level INFO
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $TagArg = if ($Version -ne "latest") { @("--branch", $Version) } else { @() }
        & git clone --depth 1 @TagArg "https://github.com/Comfy-Org/ComfyUI.git" $SourceDir
    } else {
        # Fallback archive download if git is not on path
        $ArchiveUrl = if ($Version -ne "latest") {
            "https://github.com/Comfy-Org/ComfyUI/archive/refs/tags/$Version.zip"
        } else {
            "https://github.com/Comfy-Org/ComfyUI/archive/refs/heads/master.zip"
        }
        $ZipPath = Join-Path $env:CLAUSE_TEMP_DIR "comfyui.zip"
        $ExtractTarget = Join-Path $env:CLAUSE_TEMP_DIR "comfy_extract"

        Get-File -Url $ArchiveUrl -OutFile $ZipPath
        Expand-HermeticArchive -ArchivePath $ZipPath -DestinationPath $ExtractTarget
        Install-ExtractedArchive -ExtractTarget $ExtractTarget -DestinationPath $SourceDir
        Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
    }
}

# ==============================================================================
# 3. PROVISION ISOLATED PYTHON 3.12 VIA UV
# ==============================================================================
Write-ClauseLog "Provisioning standalone hermetic Python 3.12 into $PrivatePyDir..." -Level DEBUG
& $UvExe python install --no-bin --no-registry 3.12
if ($LASTEXITCODE -ne 0) { throw "uv python install failed with code $LASTEXITCODE" }

$BasePython = (& $UvExe python find 3.12 2>$null).Trim()
if (-not $BasePython -or -not (Test-Path $BasePython)) {
    throw "Unable to locate provisioned Python 3.12 in $PrivatePyDir"
}

if (-not (Test-Path $PythonBin)) {
    Write-ClauseLog "Creating ComfyUI virtual environment at $VenvDir..." -Level DEBUG
    & $UvExe venv $VenvDir --python "$BasePython"
    if ($LASTEXITCODE -ne 0) { throw "uv venv failed with code $LASTEXITCODE" }
}

Set-Content -Path (Join-Path $VenvDir ".comfyui-owned") -Value "" -ErrorAction SilentlyContinue

# ==============================================================================
# 4. HARDWARE-AWARE PYTORCH FOUNDATION SELECTION
# ==============================================================================
$PyTorchBaseUrl = "https://download.pytorch.org/whl"
$TorchIndexUrl  = "$PyTorchBaseUrl/cpu"
$TorchPackages  = @("torch", "torchvision", "torchaudio")
$IsAmdWindows   = $false

if ($IsOSMac) {
    Write-ClauseLog "Targeting Apple Silicon / macOS CPU-MPS runtime." -Level INFO
    $TorchIndexUrl = "$PyTorchBaseUrl/cpu"
} elseif ($IsOSWindows) {
    # ── Windows Hardware Probing ──
    $NvidiaDetected = $false
    $CudaMajor = 0
    $CudaMinor = 0

    if (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue) {
        $SmiOut = & nvidia-smi.exe 2>$null
        if ($LASTEXITCODE -eq 0 -and $SmiOut -match 'CUDA(?: UMD)? Version:\s+(\d+)\.(\d+)') {
            $NvidiaDetected = $true
            $CudaMajor = [int]$Matches[1]
            $CudaMinor = [int]$Matches[2]
        }
    }

    if ($NvidiaDetected) {
        $CudaTag = if ($CudaMajor -ge 13) { "cu130" }
                   elseif ($CudaMajor -eq 12 -and $CudaMinor -ge 8) { "cu128" }
                   elseif ($CudaMajor -eq 12 -and $CudaMinor -ge 6) { "cu126" }
                   else { "cu124" }

        $TorchIndexUrl = "$PyTorchBaseUrl/$CudaTag"
        Write-ClauseLog "Detected NVIDIA GPU (CUDA $CudaMajor.$CudaMinor) -> Target Index: $TorchIndexUrl" -Level INFO
    } else {
        # Check AMD on Windows
        $AmdGpu = $false
        try {
            $AmdAdapter = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "AMD|Radeon" } | Select-Object -First 1
            if ($AmdAdapter) { $AmdGpu = $true }
        } catch {}

        if ($AmdGpu) {
            $IsAmdWindows = $true
            $TorchIndexUrl = "https://stable.repo.amd.com/rocm/whl-next/"
            $TorchPackages = @(
                "torch[device-all]==2.13.0+rocm10.0.0",
                "torchvision[device-all]==0.28.0+rocm10.0.0",
                "torchaudio==2.11.0.2+rocm10.0.0"
            )
            Write-ClauseLog "Detected AMD GPU on Windows -> Target Index: AMD ROCm 10.0 Multi-Arch" -Level INFO
        } else {
            # Check Intel XPU
            $IntelGpu = $false
            try {
                $IntelAdapter = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match "Intel.*(Arc|Data Center GPU)" } | Select-Object -First 1
                if ($IntelAdapter) { $IntelGpu = $true }
            } catch {}

            if ($IntelGpu) {
                $TorchIndexUrl = "$PyTorchBaseUrl/xpu"
                Write-ClauseLog "Detected Intel Arc / XPU device -> Target Index: $TorchIndexUrl" -Level INFO
            } else {
                Write-ClauseLog "No GPU acceleration detected. Defaulting to CPU PyTorch." -Level WARN
            }
        }
    }
} else {
    # ── Linux Hardware Probing ──
    $NvidiaDetected = $false
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        $SmiOut = & nvidia-smi 2>$null
        if ($LASTEXITCODE -eq 0 -and $SmiOut -match 'CUDA(?: UMD)? Version:\s+(\d+)\.(\d+)') {
            $NvidiaDetected = $true
            $CudaMajor = [int]$Matches[1]
            $CudaMinor = [int]$Matches[2]
        }
    }

    if ($NvidiaDetected) {
        $CudaTag = if ($CudaMajor -ge 13) { "cu130" }
                   elseif ($CudaMajor -eq 12 -and $CudaMinor -ge 8) { "cu128" }
                   elseif ($CudaMajor -eq 12 -and $CudaMinor -ge 6) { "cu126" }
                   else { "cu124" }

        $TorchIndexUrl = "$PyTorchBaseUrl/$CudaTag"
        Write-ClauseLog "Detected NVIDIA GPU (CUDA $CudaMajor.$CudaMinor) -> Target Index: $TorchIndexUrl" -Level INFO
    } elseif ((Test-Path "/dev/kfd") -or (Get-Command rocminfo -ErrorAction SilentlyContinue)) {
        $TorchIndexUrl = "$PyTorchBaseUrl/rocm7.2"
        Write-ClauseLog "Detected AMD ROCm Acceleration -> Target Index: $TorchIndexUrl" -Level INFO
    } elseif (Test-Path "/dev/dri") {
        $IsIntelArc = $false
        if (Get-Command lspci -ErrorAction SilentlyContinue) {
            $LspciOut = & lspci -nn 2>$null
            if ($LspciOut -match 'VGA compatible controller.*Intel.*(Arc|Data Center GPU|7d55|5690|56a0)') {
                $IsIntelArc = $true
            }
        }
        if ($IsIntelArc) {
            $TorchIndexUrl = "$PyTorchBaseUrl/xpu"
            Write-ClauseLog "Detected Intel Arc / XPU device -> Target Index: $TorchIndexUrl" -Level INFO
        } else {
            Write-ClauseLog "No GPU acceleration detected. Defaulting to CPU PyTorch." -Level WARN
        }
    }
}

# ==============================================================================
# 5. INSTALL DEPENDENCIES
# ==============================================================================
Write-ClauseLog "Installing PyTorch dependencies ($TorchIndexUrl)..." -Level INFO
& $UvExe pip install --python $PythonBin `
    --default-index $TorchIndexUrl `
    $TorchPackages
if ($LASTEXITCODE -ne 0) { throw "PyTorch installation failed with exit code $LASTEXITCODE" }

# Install ComfyUI requirements.txt
$ReqFile = Join-Path $SourceDir "requirements.txt"
if (Test-Path $ReqFile) {
    Write-ClauseLog "Installing ComfyUI requirements..." -Level INFO

    $IsMacIntel = $false
    if ($IsOSMac) {
        $Arch = (uname -m 2>$null).Trim()
        if ($Arch -eq "x86_64") {
            $IsMacIntel = $true
        }
    }

    if ($IsMacIntel) {
        Write-ClauseLog "Intel Mac (x86_64) detected: Filtering non-x86_64 wheels (e.g. comfy-angle)..." -Level WARN
        
        # Filter out comfy-angle from requirements for macOS x86_64 runner compatibility
        $FilteredReq = Join-Path $env:CLAUSE_TEMP_DIR "comfy_req_mac_intel_$PID.txt"
        Get-Content -Path $ReqFile | Where-Object { 
            $_ -notmatch '^\s*comfy-angle'
        } | Set-Content -LiteralPath $FilteredReq -Encoding UTF8

        try {
            & $UvExe pip install --python $PythonBin -r $FilteredReq
            if ($LASTEXITCODE -ne 0) { throw "ComfyUI requirements installation failed with code $LASTEXITCODE" }
        } finally {
            if (Test-Path $FilteredReq) {
                Remove-Item -LiteralPath $FilteredReq -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        & $UvExe pip install --python $PythonBin -r $ReqFile
        if ($LASTEXITCODE -ne 0) { throw "ComfyUI requirements installation failed with code $LASTEXITCODE" }
    }
}

# ==============================================================================
# 6. GENERATE APPLICATION SHIMS
# ==============================================================================
if ($IsOSWindows) {
    $CmdShim = Join-Path $ShimDir "comfyui.bat"
    @"
@echo off
setlocal
"%~dp0..\venv\Scripts\python.exe" "%~dp0..\src\main.py" %*
exit /b %ERRORLEVEL%
"@ | Set-Content -LiteralPath $CmdShim -Encoding ASCII
} else {
    $ShShim = Join-Path $ShimDir "comfyui"
    @"
#!/usr/bin/env sh
exec "\$(dirname "\$0")/../venv/bin/python" "\$(dirname "\$0")/../src/main.py" "\$@"
"@ | Set-Content -LiteralPath $ShShim -Encoding UTF8
    Set-PosixExecutable -FilePath $ShShim
}

Write-ClauseLog "ComfyUI Studio engine successfully provisioned." -Level INFO