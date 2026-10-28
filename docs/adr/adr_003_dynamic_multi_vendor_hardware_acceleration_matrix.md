# ADR 003: Dynamic Multi-Vendor Hardware Acceleration Matrix

- **Status**: Accepted
- **Date**: 2026-10-28
- **Context**: Hardware Detection and PyTorch Wheel Selection

## Context and Problem Statement

Modern AI execution frameworks (such as Unsloth, ComfyUI, vLLM, and PyTorch-based training/inference engines) require hardware-specific acceleration backends to achieve production-grade performance. Deploying across disparate operating systems and architectures faces multiple fatal failure modes:

1. **Hardcoded CUDA Dependencies**: Hardcoding CUDA indices causes immediate installation or runtime failures on AMD ROCm, Intel Arc, Apple Silicon, or headless CPU runners.
2. **NVIDIA Microarchitecture Drift**: Older NVIDIA architectures (e.g., Turing or Pascal) fail to run modern CUDA 12.8+ kernels due to missing PTX/SASS instruction sets, while modern Ada Lovelace, Hopper, and Blackwell GPUs require newer CUDA runtimes (cu126, cu128, cu130).
3. **AMD Fragmentation**: AMD ROCm on Linux uses unified index repositories (`rocm7.2`), whereas Windows requires multi-architecture device packages (`device-all` or `device-gfx*`) from dedicated AMD package mirrors (`whl-next`).
4. **Intel Arc / Core Ultra Support**: Intel Arc discrete GPUs and Core Ultra APUs require PyTorch's native XPU backend index rather than standard CPU or CUDA wheels.
5. **macOS Architecture Bifurcation**: Modern PyTorch releases support Apple Silicon (`arm64`) with native Metal Performance Shaders (`mps`), but have dropped prebuilt wheels for macOS Intel (`x86_64`). Furthermore, secondary libraries (such as `comfy-angle`) publish wheels exclusively for `arm64`, failing resolution entirely on `x86_64` macOS environments.

## Decision Outcome

All ClauseOS `renv` installers implement a unified, automated 5-way hardware detection and index resolution matrix prior to any package resolution or installation.

### Architecture Flow

```text
                          [ Detect Operating System & Architecture ]
                                          |
        +---------------------------------+---------------------------------+
        |                                 |                                 |
     Windows                            Linux                             macOS
        |                                 |                                 |
+-------+-------+                 +-------+-------+                 +-------+-------+
|   |   |   |   |                 |   |   |   |   |                 |               |
NV AMD INT CPU DIS             NV  AMD INT CPU DIS              ARM64           x86_64
|   |   |   |   |                 |   |   |   |   |                 |               |
v   v   v   v   v                 v   v   v   v   v                 v               v
CUDA ROCm XPU CPU               CUDA ROCm XPU CPU                  MPS          CPU Fallback
12/13 10.0 whl  whl             12/13 7.2 whl  whl                 (Metal)     (Filter comfy-angle)
```

### Detection & Resolution Implementation

#### 1. NVIDIA CUDA Matrix
- Probes `nvidia-smi` to extract major and minor CUDA driver versions.
- Dynamically selects matching index repositories:
  - $\text{CUDA} \ge 13.0 \rightarrow \texttt{https://download.pytorch.org/whl/cu130}$
  - $\text{CUDA} = 12.8 \rightarrow \texttt{https://download.pytorch.org/whl/cu128}$
  - $\text{CUDA} = 12.6 \rightarrow \texttt{https://download.pytorch.org/whl/cu126}$
  - $\text{CUDA} \le 12.4 \rightarrow \texttt{https://download.pytorch.org/whl/cu124}$

#### 2. AMD ROCm Matrix
- **Linux**: Probes `/dev/kfd` and `rocminfo`. Targets index `https://download.pytorch.org/whl/rocm7.2`.
- **Windows**: Queries `Get-CimInstance Win32_VideoController` for AMD/Radeon devices. Resolves to AMD's multi-architecture distribution mirror `https://stable.repo.amd.com/rocm/whl-next/` with `device-all` extras.

#### 3. Intel Arc / XPU Matrix
- Probes PCI IDs (`lspci`) or `Win32_VideoController` for Intel Arc or Data Center GPU entries.
- Resolves to `https://download.pytorch.org/whl/xpu`.

#### 4. macOS / Apple Silicon Matrix
- **Apple Silicon (`arm64`)**: Binds native PyPI / CPU-MPS wheels with Metal acceleration. Retains all core wheels and desktop acceleration packages.
- **Intel Mac (`x86_64`)**: Binds CPU fallback wheels and applies a build-safe requirement filter to strip unsupported packages (e.g., `comfy-angle`), enabling headless validation without resolution crashes.

#### 5. Graceful CPU Fallback
- When no compatible discrete accelerator is identified, or when driver query timeouts occur, the installer defaults to `https://download.pytorch.org/whl/cpu` with diagnostic logs.

### Consequences

#### Positive
- Single unified installation recipe runs without modification across all local developer machines, GPU servers, and continuous integration runners.
- Eliminates manual driver mapping and prevents broken wheel installations.
- Completely avoids virtualization overhead while preserving direct bare-metal GPU driver communication.

#### Negative
- Hardware probing commands (`nvidia-smi`, `lspci`, `Get-CimInstance`) introduce a minor (sub-second) initialization check during first-time runtime provisioning.