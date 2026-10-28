<div align="center">

# ⚡ ClauseOS (`clause.os`)

**Autonomous, Hermetic Single-Driver OS Environment & Air-Gapped Cloud Bursting Platform**

[![CI / CD Matrix](https://img.shields.io/badge/CI%2FCD-100%25%20Passing-brightgreen?style=for-the-badge&logo=githubactions&logoColor=white)](#)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Linux%20%7C%20macOS-blue?style=for-the-badge&logo=linux&logoColor=white)](#)
[![Isolation](https://img.shields.io/badge/Confinement-Zero--Contamination%20Bare--Metal-orange?style=for-the-badge&logo=buffer&logoColor=white)](#)
[![Hardware Acceleration](https://img.shields.io/badge/Hardware-CUDA%20%7C%20ROCm%20%7C%20XPU%20%7C%20MPS-purple?style=for-the-badge&logo=nvidia&logoColor=white)](#)

<p align="center">
  <a href="#-overview">Overview</a> •
  <a href="#-core-architectural-pillars">Architectural Pillars</a> •
  <a href="#-operating-system-primitives-mapping">OS Primitives</a> •
  <a href="#-canonical-directory-hierarchy">Directory Layout</a> •
  <a href="#-hardware-acceleration-matrix">Hardware Matrix</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-cloud-bursting--detachment">Cloud Bursting</a> •
  <a href="#-architecture-decision-records">ADRs</a>
</p>

</div>

---

## 🧭 Overview

**ClauseOS** is a bare-metal, self-contained operating system environment architecture designed to execute directly on the host machine while operating entirely within a hermetically confined profile directory (`.home/`). By redirecting `$HOME`, `$USERPROFILE`, and standard OS directory structures strictly into this localized root, ClauseOS eliminates host-level package managers, path pollution, global registry tampering, and configuration drift.

ClauseOS functions as an **Air-Gapped Seed Node**: a mobile command center capable of operating offline, self-bootstrapping isolated developer toolchains and specialized neural runtimes, bursting infrastructure into remote clouds via Pulumi, and cleanly detaching while cloud clusters continue autonomous operations.

Unlike virtual machines or Docker containers, ClauseOS introduces **zero hypervisor overhead** and grants applications unhindered, direct bare-metal access to hardware acceleration pipelines (NVIDIA CUDA, AMD ROCm, Intel XPU, and Apple Silicon MPS).

---

## 🏛️ Core Architectural Pillars

### 1. 🛡️ True Bare-Metal Hermetic Confinement
* **Immutable State Root (`.home/`):** All configurations, state stores, caches, and application data reside inside `CLAUSE_PROJECT_ROOT/.home`.
* **Zero Global Pollution:** Deleting `.home/` completely resets the environment to a pristine state without leaving residual files, PATH edits, or registry entries on the host machine.
* **Automated Hermeticity Assertions:** Continuous CI/CD testing (`tests/system/test_hermeticity.nu`) guarantees zero host path leakage or shell delimiter bleeding.

### 2. ⚙️ Two-Tier Orchestration Model (`mise` + `renv`)
* **Stage 1 & 2 (Base Tools):** Managed via `mise` (`.mise.toml`), provisioning core developer runtimes (`uv`, `just`, `git`, `nu`, `pulumi`).
* **Stage 3 (`renv` Application Layer):** Custom, isolated runtime environments provisioned on-demand via standalone `uv` into dedicated virtual environments (`apps/<name>/venv`), each having an independent CPython installation and zero cross-package contamination.

### 3. 🎯 5-Way Dynamic Hardware Matrix
* Automatic, non-blocking hardware inspection during boot.
* Intelligently selects, binds, and downloads optimal PyTorch wheels across **NVIDIA CUDA** (`cu124`–`cu130`), **AMD ROCm** (ROCm 7.2 on Linux, ROCm 10.0 multi-arch on Windows), **Intel Arc/XPU**, **Apple Silicon MPS**, with defensive CPU fallback.

### 4. 🐚 Polyglot Cross-Shell Integrity
* Unified Stage 0 bootloader trampolines (`cx.bat`, `cx.ps1`, `cx.sh`) normalizing cross-platform delimiters (`;` on Windows vs. `:` on POSIX) and symlink resolution differences (`/var` vs `/private/var` on macOS).
* Boots into **Nushell** as the primary interactive workbench shell.

---

## 🧩 Operating System Primitives Mapping

ClauseOS maps userland binaries and services directly into functional OS system primitives:

| OS Primitive | ClauseOS Component | Hermetic Target Location | System Function |
| :--- | :--- | :--- | :--- |
| **Microkernel / Exec** | `boot.ps1` / `cx.*` | `CLAUSE_PROJECT_ROOT/scripts/core/boot.ps1` | Stage 0 bootloader & sandbox barrier enforcement |
| **Shell & Init (PID 1)** | Nushell (`nu`) | `.home/AppData/Local/Programs/bin/nu` or `.home/.local/bin/nu` | Interactive command processor & process supervisor |
| **Driver & HAL** | Mise | `.home/.../bin/mise` | Unified toolchain driver & dynamic runtime manager |
| **Task Scheduler** | Just | `.home/.../bin/just` | Task runner for system workflows & operational recipes |
| **Private Python Driver** | `uv` (Astral) | `.home/.../bin/uv` | Hermetic virtual environment & wheel resolution engine |
| **AI Fine-Tuning Engine**| Unsloth | `.home/.../apps/unsloth/` | Hardware-accelerated LLM parameter-efficient training |
| **Neural Studio** | ComfyUI | `.home/.../apps/comfyui/` | Node-based diffusion model inference & visual studio |
| **Neural Coprocessors** | Lemonade / FastFlowLM | `.home/.../apps/lemonade/` | Embedded LLM inference daemons & background agents |
| **Window Manager / UI** | Portable VS Code | `.home/.../apps/vscode/` | Primary graphical development cockpit |
| **Concurrency Engine** | Erlang (BEAM) / Gleam | `.home/.../mise/installs/erlang` | Fault-tolerant distributed actor subsystem |
| **Infra Kernel** | Pulumi CLI | `.home/.../apps/pulumi/` | Multi-cloud resource orchestration & state engine |
| **Workload Scheduler** | HashiCorp Nomad | `.home/.../bin/nomad` | Distributed job & container orchestrator |
| **Service Registry** | HashiCorp Consul | `.home/.../bin/consul` | Service discovery, mesh DNS, & Raft consensus |
| **Secrets Engine** | HashiCorp Vault | `.home/.../bin/vault` | Cryptographic key storage & identity management |

---

## 📂 Canonical Directory Hierarchy

ClauseOS maps platform-specific conventions directly into the `.home/` sandbox:

```text
CLAUSE_PROJECT_ROOT/
├── .home/                                # Hermetic Root ($HOME & $USERPROFILE)
│   ├── AppData/Local/Programs/           # [Windows] Binaries, apps, and logs
│   │   ├── bin/                          # Unified Stage 0/1 binaries & Mise shims
│   │   ├── apps/                         # Standalone 'renv' deployments
│   │   │   ├── unsloth/                  # Isolated Python + Unsloth venv
│   │   │   ├── comfyui/                  # Isolated Python + ComfyUI venv & src
│   │   │   ├── vscode/                   # Portable VS Code distribution
│   │   │   └── pulumi/                   # Pulumi engine & plugins
│   │   └── logs/                         # Bootstrap & system execution logs
│   ├── .local/                           # [POSIX] Linux / macOS Application & Binary Root
│   │   ├── bin/                          # Unified binaries & shims
│   │   ├── apps/                         # Standalone 'renv' applications
│   │   ├── logs/                         # Bootstrap & execution logs
│   │   └── share/                        # Persistent shared application data (Mise data)
│   ├── .config/                          # [POSIX] XDG Config Home (Mise config, etc.)
│   ├── .cache/                           # Cache root (uv cache, download staging, temporary runtimes)
│   └── .gitconfig                        # Isolated Git user identity file
├── docs/
│   └── adr/                              # Architecture Decision Records (ADRs)
├── ops/                                  # Pulumi Cloud Infrastructure stacks
├── packages/                             # Custom internal packages & language extensions
├── projects/                             # User projects & workspace repositories
├── scripts/
│   ├── cli/
│   │   ├── nu/config/                    # Nushell canonical configs (env.nu, config.nu, mise.nu)
│   │   └── pwsh/
│   │       ├── installers/               # Stage 1 pre-Mise bootstrap installers
│   │       └── renv/                     # Stage 3 post-Mise runtime environment recipes
│   └── core/
│       └── boot.ps1                      # Microkernel boot engine
├── tests/
│   └── system/                           # Automated hermeticity and stage verification suites
├── .clause.toml                          # Central OS manifest & application toggle declarations
├── .mise.toml                            # Toolchain dependency & version manifest
├── justfile                              # Operational task commands
├── cx.bat                                # Windows Entrypoint Trampoline
├── cx.ps1                                # PowerShell Entrypoint Trampoline
└── cx.sh                                 # POSIX (Linux/macOS) Entrypoint Trampoline
```

---

## ⚡ Hardware Acceleration Matrix

ClauseOS dynamically queries the host hardware at runtime to resolve and inject the correct binary index without requiring host driver installations:

```text
                                [ Hardware Probing Subsystem ]
                                               │
             ┌─────────────────────────────────┼─────────────────────────────────┐
             ▼                                 ▼                                 ▼
        [ Windows ]                        [ Linux ]                         [ macOS ]
             │                                 │                                 │
     ┌───────┴───────┐                 ┌───────┴───────┐                 ┌───────┴───────┐
     ▼               ▼                 ▼               ▼                 ▼               ▼
  NVIDIA            AMD             NVIDIA            AMD             Apple Silicon    Intel
(CUDA 12/13)    (ROCm 10.0)      (CUDA 12/13)     (ROCm 7.2)         (Native MPS)   (CPU Fallback)
```

* **NVIDIA CUDA:** Probes driver version via `nvidia-smi` and maps to `cu124`, `cu126`, `cu128`, or `cu130`.
* **AMD ROCm (Linux):** Probes `/dev/kfd` and `rocminfo`, targeting `https://download.pytorch.org/whl/rocm7.2`.
* **AMD ROCm (Windows):** Queries `Win32_VideoController` and configures AMD multi-architecture wheels (`torch[device-all]==2.13.0+rocm10.0.0`).
* **Intel Arc (XPU):** Detects Arc GPUs and binds `https://download.pytorch.org/whl/xpu`.
* **Apple Silicon (macOS `arm64`):** Leverages native Apple Metal Performance Shaders (`mps`).
* **macOS Intel (`x86_64`):** Gracefully falls back to CPU execution and automatically filters out unsupported architecture wheels (e.g. `comfy-angle`) to avoid dependency resolution errors.

---

## 🚀 Quick Start

### 1. Launch the Microkernel Bootloader

Run the unified `cx` command for your platform. This provisions Stage 0 tools, initializes directory anchors, configures `.home/`, syncs `.mise.toml`, runs active `renv` recipes, and drops you into the hermetic Nushell environment:

**Windows (CMD / PowerShell):**
```cmd
cx
```

**Linux / macOS (POSIX Shell):**
```bash
./cx.sh
```

### 2. Verify State Hermeticity

Once inside the ClauseOS Nushell session, verify that your environment is completely confined to `.home/`:

```nushell
just test-hermeticity
```

### 3. Launch AI Workloads

Launch any pre-configured AI engine directly via its isolated shim:

```nushell
# Run Unsloth CLI
unsloth --help

# Launch ComfyUI Studio
comfyui --listen 127.0.0.1 --port 8188
```

---

## ☁️ Cloud Bursting & Detachment Flow

ClauseOS acts as an air-gapped seed node. It provisions remote cloud infrastructure (AWS, GCP, Azure, Hetzner, Bare Metal) using embedded Pulumi and HashiStack primitives, promotes remote nodes to quorum, and detaches cleanly:

```nushell
# 1. Burst local workspace state to cloud infrastructure
clause cloud up

# 2. Verify remote Nomad & Consul cluster consensus
clause cluster status

# 3. Sever local connection (Local node drains; Cloud cluster continues autonomous execution)
clause cloud detach
```

---

## 📚 Architecture Decision Records (ADRs)

Key architectural decisions are documented under `docs/adr/`:

* [**ADR 0001**: Hermetic State Confinement and Canonical Directory Hierarchy](docs/adr/0001-hermetic-state-confinement-and-canonical-directory-hierarchy.md)
* [**ADR 0002**: Two-Tier Toolchain Orchestration (`mise` and `renv`)](docs/adr/0002-two-tier-toolchain-orchestration-mise-and-renv.md)
* [**ADR 0003**: Dynamic Multi-Vendor Hardware Acceleration Matrix](docs/adr/0003-dynamic-multi-vendor-hardware-acceleration-matrix.md)
* [**ADR 0004**: Cross-Shell Environment and PATH Delimiter Canonicalization](docs/adr/0004-cross-shell-environment-and-path-delimiter-canonicalization.md)

---

<div align="center">

Built With ❤️ By Vieo

</div>