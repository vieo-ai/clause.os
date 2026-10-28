param(
    [Parameter(Mandatory = $true)] [string]$Version
)
$ErrorActionPreference = 'Stop'

# ==============================================================================
# 1. RESOLVE PATHS & ENFORCE HERMETIC SANDBOX
# ==============================================================================
$TargetDir     = Join-Path $env:CLAUSE_APPS_DIR "unsloth"
$VenvDir       = Join-Path $TargetDir "venv"
$PrivatePyDir  = Join-Path $TargetDir "python"
$ExeExt        = if ($IsOSWindows) { ".exe" } else { "" }
$ScriptDir     = if ($IsOSWindows) { "Scripts" } else { "bin" }
$PythonBin     = Join-Path $VenvDir "$ScriptDir\python$ExeExt"
$ShimDir       = Join-Path $TargetDir "bin"
$ShimExe       = Join-Path $ShimDir "unsloth$ExeExt"

# Fast-path idempotency check
if ((Test-Path $PythonBin) -and ((Test-Path $ShimExe) -or (Test-Path (Join-Path $ShimDir "unsloth.bat")) -or (Test-Path (Join-Path $ShimDir "unsloth")))) {
    return
}

# Locate uv (Mise managed, CLAUSE_BIN_DIR, or PATH)
$UvExe = $null
$DirectUv = Join-Path $env:CLAUSE_BIN_DIR "uv$ExeExt"
if (Test-Path $DirectUv) {
    $UvExe = $DirectUv
} else {
    $CommandUv = Get-Command uv$ExeExt -ErrorAction SilentlyContinue
    if ($CommandUv) {
        $UvExe = $CommandUv.Source
    } else {
        $MiseShims = Join-Path $env:CLAUSE_HOME (if ($IsOSWindows) { "AppData\Local\mise\shims\uv.exe" } else { ".local/share/mise/shims/uv" })
        if (Test-Path $MiseShims) {
            $UvExe = $MiseShims
        }
    }
}

if (-not $UvExe) {
    Write-ClauseLog "uv package manager missing. Ensure 'uv' is seeded or installed via Mise." -Level FATAL
    throw "[ClauseOS] Missing prerequisite: uv"
}

Write-ClauseLog "Initializing Hermetic Unsloth AI Engine Deployment ($Version)..." -Level INFO

# Provision target directories inside apps/unsloth/
@($TargetDir, $ShimDir, $PrivatePyDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
}

# Confine all uv downloads and runtime stores strictly to .home
$env:UV_CACHE_DIR          = Join-Path $env:CLAUSE_CACHE_DIR "uv"
$env:UV_PYTHON_INSTALL_DIR = $PrivatePyDir

# ==============================================================================
# 2. HARDWARE ACCELERATION DETECTION MATRIX (CUDA / ROCm / XPU / MPS / CPU)
# ==============================================================================
$PyTorchBaseUrl = "https://download.pytorch.org/whl"
$TorchIndexUrl  = "$PyTorchBaseUrl/cpu"
$ExtraArgs      = @()
$SkipTorch      = $false

if ($IsOSMac) {
    # ── macOS Platform Handling ──
    $MacArch = (uname -m 2>$null).Trim()
    if ($MacArch -eq "arm64") {
        Write-ClauseLog "Detected Apple Silicon (MPS / Metal acceleration)." -Level INFO
        $TorchIndexUrl = "$PyTorchBaseUrl/cpu"
    } else {
        Write-ClauseLog "Intel Mac (x86_64) detected: PyTorch unsupported, running in GGUF-only mode." -Level WARN
        $SkipTorch = $true
    }
} elseif ($IsOSWindows) {
    # ── Windows Platform Handling ──
    $NvidiaDetected = $false
    $CudaMajor = 0
    $CudaMinor = 0
    $SmArch = 0

    # 1. Probe NVIDIA
    if (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue) {
        $SmiOut = & nvidia-smi.exe 2>$null
        if ($LASTEXITCODE -eq 0 -and $SmiOut -match 'CUDA(?: UMD)? Version:\s+(\d+)\.(\d+)') {
            $NvidiaDetected = $true
            $CudaMajor = [int]$Matches[1]
            $CudaMinor = [int]$Matches[2]

            $SmOut = & nvidia-smi.exe --query-gpu=compute_cap --format=csv,noheader,nounits 2>$null
            if ($SmOut -match '^(\d+)\.(\d+)') {
                $SmArch = ([int]$Matches[1] * 10) + [int]$Matches[2]
            }
        }
    }

    if ($NvidiaDetected) {
        $CudaTag = "cu124"
        if ($CudaMajor -ge 13) { $CudaTag = "cu130" }
        elseif ($CudaMajor -eq 12 -and $CudaMinor -ge 8) { $CudaTag = "cu128" }
        elseif ($CudaMajor -eq 12 -and $CudaMinor -ge 6) { $CudaTag = "cu126" }
        elseif ($CudaMajor -ge 12) { $CudaTag = "cu124" }
        elseif ($CudaMajor -ge 11) { $CudaTag = "cu118" }

        # Cap pre-Turing (sm < 75) to cu126
        if ($SmArch -gt 0 -and $SmArch -lt 75 -and ($CudaTag -in @("cu128", "cu130"))) {
            Write-ClauseLog "Pre-Turing NVIDIA GPU (sm_$SmArch < sm_75) detected -> Capping to cu126." -Level WARN
            $CudaTag = "cu126"
        }

        $TorchIndexUrl = "$PyTorchBaseUrl/$CudaTag"
        Write-ClauseLog "Detected NVIDIA GPU (CUDA $CudaMajor.$CudaMinor) -> Target Index: $TorchIndexUrl" -Level INFO
    } else {
        # 2. Probe AMD ROCm on Windows
        $RocmGfx = $null
        try {
            $AmdGpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "AMD|Radeon" } | Select-Object -First 1

            if ($AmdGpu) {
                $Name = $AmdGpu.Name
                if ($Name -match '9070|9080|R9700') { $RocmGfx = "gfx1201" }
                elseif ($Name -match '9060') { $RocmGfx = "gfx1200" }
                elseif ($Name -match '8065S|8060S|8050S|8040S|Strix Halo|Ryzen AI Max') { $RocmGfx = "gfx1151" }
                elseif ($Name -match '890M|880M|Strix Point|HX 37') { $RocmGfx = "gfx1150" }
                elseif ($Name -match '860M|840M|Krackan') { $RocmGfx = "gfx1152" }
                elseif ($Name -match 'RX 7900|PRO W7900|PRO W7800') { $RocmGfx = "gfx1100" }
                elseif ($Name -match 'RX 7800|RX 7700') { $RocmGfx = "gfx1101" }
                elseif ($Name -match 'RX 7600|RX 7650|PRO W7600') { $RocmGfx = "gfx1102" }
                elseif ($Name -match '780M|760M|Phoenix|Hawk Point') { $RocmGfx = "gfx1103" }
                elseif ($Name -match 'RX 6900|RX 6800|RX 6700') { $RocmGfx = "gfx1030" }
                elseif ($Name -match 'RX 6600|PRO W6600') { $RocmGfx = "gfx1032" }
            }
        } catch {}

        if ($RocmGfx) {
            $MultiArchGfx = @("gfx1100", "gfx1101", "gfx1102", "gfx1103", "gfx1150", "gfx1151", "gfx1152", "gfx1200", "gfx1201")
            if ($MultiArchGfx -contains $RocmGfx) {
                $TorchIndexUrl = "https://repo.amd.com/rocm/whl-multi-arch/"
                Write-ClauseLog "Detected AMD GPU ($RocmGfx) -> Target Index: Multi-Arch ROCm" -Level INFO
            } else {
                $TorchIndexUrl = "https://repo.amd.com/rocm/whl/$RocmGfx/"
                Write-ClauseLog "Detected AMD GPU ($RocmGfx) -> Target Index: $TorchIndexUrl" -Level INFO
            }
        } else {
            # 3. Probe Intel Arc / XPU
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
                Write-ClauseLog "No discrete GPU detected. Falling back to CPU PyTorch." -Level WARN
            }
        }
    }
} else {
    # ── Linux Platform Handling ──
    $NvidiaDetected = $false
    $CudaMajor = 0
    $CudaMinor = 0
    $SmArch = 0

    # 1. Probe NVIDIA
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        $SmiOut = & nvidia-smi 2>$null
        if ($LASTEXITCODE -eq 0 -and $SmiOut -match 'CUDA(?: UMD)? Version:\s+(\d+)\.(\d+)') {
            $NvidiaDetected = $true
            $CudaMajor = [int]$Matches[1]
            $CudaMinor = [int]$Matches[2]

            $SmOut = & nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits 2>$null
            if ($SmOut -match '^(\d+)\.(\d+)') {
                $SmArch = ([int]$Matches[1] * 10) + [int]$Matches[2]
            }
        }
    }

    if ($NvidiaDetected) {
        $CudaTag = "cu124"
        if ($CudaMajor -ge 13) { $CudaTag = "cu130" }
        elseif ($CudaMajor -eq 12 -and $CudaMinor -ge 8) { $CudaTag = "cu128" }
        elseif ($CudaMajor -eq 12 -and $CudaMinor -ge 6) { $CudaTag = "cu126" }
        elseif ($CudaMajor -ge 12) { $CudaTag = "cu124" }
        elseif ($CudaMajor -ge 11) { $CudaTag = "cu118" }

        # Cap pre-Turing (sm < 75) to cu126
        if ($SmArch -gt 0 -and $SmArch -lt 75 -and ($CudaTag -in @("cu128", "cu130"))) {
            Write-ClauseLog "Pre-Turing NVIDIA GPU (sm_$SmArch < sm_75) detected -> Capping to cu126." -Level WARN
            $CudaTag = "cu126"
        }

        $TorchIndexUrl = "$PyTorchBaseUrl/$CudaTag"
        Write-ClauseLog "Detected NVIDIA GPU (CUDA $CudaMajor.$CudaMinor) -> Target Index: $TorchIndexUrl" -Level INFO
    } elseif ((Test-Path "/dev/kfd") -or (Get-Command rocminfo -ErrorAction SilentlyContinue)) {
        # 2. Probe AMD ROCm on Linux
        $RocmTag = "rocm6.2"
        if (Get-Command rocminfo -ErrorAction SilentlyContinue) {
            $RocmInfo = & rocminfo 2>$null
            if ($RocmInfo -match 'ROCm Version:\s*(\d+\.\d+)') {
                $RocmTag = "rocm" + $Matches[1]
            }
        }
        $TorchIndexUrl = "$PyTorchBaseUrl/$RocmTag"
        Write-ClauseLog "Detected AMD ROCm Acceleration ($RocmTag) -> Target Index: $TorchIndexUrl" -Level INFO
    } elseif (Test-Path "/dev/dri") {
        # 3. Probe Intel Arc / XPU on Linux
        $IsIntelArc = $false
        if (Get-Command lspci -ErrorAction SilentlyContinue) {
            $LspciOut = & lspci -nn 2>$null
            if ($LspciOut -match 'VGA compatible controller.*Intel.*(Arc|Data Center GPU|7d55|5690|56a0)') {
                $IsIntelArc = $true
            }
        }
        if ($IsIntelArc) {
            $TorchIndexUrl = "$PyTorchBaseUrl/xpu"
            Write-ClauseLog "Detected Intel Arc / XPU acceleration -> Target Index: $TorchIndexUrl" -Level INFO
        } else {
            Write-ClauseLog "No supported GPU found. Falling back to CPU PyTorch." -Level WARN
        }
    } else {
        Write-ClauseLog "No GPU detected. Falling back to CPU PyTorch." -Level WARN
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

# ==============================================================================
# 4. ASSEMBLE VIRTUAL ENVIRONMENT & RUNTIMES
# ==============================================================================
if (-not (Test-Path $PythonBin)) {
    Write-ClauseLog "Creating Unsloth virtual environment at $VenvDir..." -Level DEBUG
    & $UvExe venv $VenvDir --python "$BasePython"
    if ($LASTEXITCODE -ne 0) { throw "uv venv failed with code $LASTEXITCODE" }
}

# Mark environment ownership
Set-Content -Path (Join-Path $VenvDir ".unsloth-studio-owned") -Value "" -ErrorAction SilentlyContinue

# ==============================================================================
# 5. INSTALL PYTORCH FOUNDATION & CORE DEPENDENCIES
# ==============================================================================
if (-not $SkipTorch) {
    Write-ClauseLog "Installing PyTorch runtime from $TorchIndexUrl..." -Level INFO
    & $UvExe pip install --python $PythonBin `
        --default-index $TorchIndexUrl `
        "torch>=2.4.0,<2.12.0" "torchvision>=0.19.0,<0.27.0" "torchaudio>=2.4.0,<2.12.0"
    if ($LASTEXITCODE -ne 0) { throw "PyTorch installation failed with code $LASTEXITCODE" }

    # If Intel XPU was chosen, inject XPU bitsandbytes
    if ($TorchIndexUrl -like "*/xpu*") {
        Write-ClauseLog "Installing Intel XPU bitsandbytes extension..." -Level DEBUG
        & $UvExe pip install --python $PythonBin --no-deps "bitsandbytes>=0.50.0"
    }

    # Pin PyTorch versions to overrides file to prevent unsloth dependency downgrade
    $InstalledTorch = (& $PythonBin -c "import importlib.metadata as m; print(m.version('torch'))" 2>$null).Trim()
    $OverrideFile   = Join-Path $env:CLAUSE_TEMP_DIR "torch_override_$PID.txt"
    "torch==$InstalledTorch`ntorchvision`ntorchaudio" | Set-Content -LiteralPath $OverrideFile -Encoding UTF8

    try {
        Write-ClauseLog "Installing Unsloth Core ($Version) locked to PyTorch $InstalledTorch..." -Level INFO
        & $UvExe pip install --python $PythonBin `
            --overrides $OverrideFile `
            "unsloth==$Version" "unsloth-zoo"
        if ($LASTEXITCODE -ne 0) { throw "Unsloth installation failed with code $LASTEXITCODE" }
    } finally {
        if (Test-Path $OverrideFile) {
            Remove-Item -LiteralPath $OverrideFile -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-ClauseLog "Installing Unsloth Core ($Version) in No-Torch Mode..." -Level INFO
    & $UvExe pip install --python $PythonBin --no-deps "unsloth==$Version" "unsloth-zoo"
    & $UvExe pip install --python $PythonBin "pydantic"
}

# ==============================================================================
# 6. GENERATE CLI TRAMPOLINES (APPLICATION CONTROL & HERMETIC BYPASS)
# ==============================================================================
$TrampolineCode = 'import sys, os; sys.argv[0] = "unsloth"; from unsloth_cli import app; sys.exit(app())'

if ($IsOSWindows) {
    # Generate CMD trampoline to bypass AppLocker / WDAC
    $CmdShim = Join-Path $ShimDir "unsloth.bat"
    @"
@echo off
setlocal
"%~dp0..\venv\Scripts\python.exe" -X utf8 -c "$TrampolineCode" %*
exit /b %ERRORLEVEL%
"@ | Set-Content -LiteralPath $CmdShim -Encoding ASCII
} else {
    # Generate POSIX shell trampoline
    $ShShim = Join-Path $ShimDir "unsloth"
    @"
#!/usr/bin/env sh
exec "\$(dirname "\$0")/../venv/bin/python" -c '$TrampolineCode' "\$@"
"@ | Set-Content -LiteralPath $ShShim -Encoding UTF8
    Set-PosixExecutable -FilePath $ShShim
}

Write-ClauseLog "Unsloth AI Engine successfully provisioned." -Level INFO