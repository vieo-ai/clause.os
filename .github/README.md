<p align="center">
  <img src="../resources/images/clause-workflow.jpg" alt="Clause OS Workflow" width="100%">
</p>
<div align="center">

# ⚡ ClauseOS (`clause.os`)

**Autonomous, Hermetic Single-Driver OS Environment & Air-Gapped Cloud Bursting Platform**

[![CI / CD Matrix](https://img.shields.io/badge/CI%2FCD-100%25%20Passing-brightgreen?style=for-the-badge&logo=githubactions&logoColor=white)](#)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Linux%20%7C%20macOS-blue?style=for-the-badge&logo=linux&logoColor=white)](#)
[![Isolation](https://img.shields.io/badge/Confinement-Zero--Contamination%20Bare--Metal-orange?style=for-the-badge&logo=buffer&logoColor=white)](#)
[![Hardware Acceleration](https://img.shields.io/badge/Hardware-CUDA%20%7C%20ROCm%20%7C%20XPU%20%7C%20MPS-purple?style=for-the-badge&logo=nvidia&logoColor=white)](#)
[![Virtual Enterprise](https://img.shields.io/badge/Agents-Autonomous%20Virtual%20Enterprise-indigo?style=for-the-badge&logo=anthropic&logoColor=white)](#)

<p align="center">
  <a href="#-overview">Overview</a> •
  <a href="#-core-architectural-pillars">Architectural Pillars</a> •
  <a href="#-operating-system-primitives-mapping">OS Primitives</a> •
  <a href="#-canonical-directory-hierarchy">Directory Layout</a> •
  <a href="#-unified-model-cache--ai-storage">AI Storage</a> •
  <a href="#-cross-platform-micro-virtualization-cx-vm">Virtualization</a> •
  <a href="#-autonomous-virtual-enterprise">Virtual Enterprise</a> •
  <a href="#-beam-distributed-backplane--gleam-orchestration">BEAM Backplane</a> •
  <a href="#-seax-carrier-language--multi-target-transpiler">Seax Language</a> •
  <a href="#-ring-rust-in-gleam-native-bridge">RinG Bridge</a> •
  <a href="#-hardware-acceleration-matrix">Hardware Matrix</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-open-core--monetization-strategy">Strategy</a> •
  <a href="#-architecture-decision-records">ADRs</a>
</p>

</div>

---

> ### 🚧 Active Development & Architectural Stabilization
> **ClauseOS is currently in rapid, heavy active development (`v0.1.5-dev`).**
> 
> * The foundational hermetic substrate, two-tier runtime, dynamic GPU auto-detection, and base toolchains are fully operational and passing 100% green CI/CD across Windows, Linux, and macOS.
> * Advanced higher-order subsystems—including complete HashiStack daemon topologies (`nomad`, `consul`, `vault`, `packer`, `boundary`), the BEAM/Gleam distributed orchestrator, Pixiecore bare-metal provisioning (MaaS), the `cx vm` hypervisor bridge, Seax (`.cx`) compiler toolchains, and the `.enterprise/` multi-agent organization schemas—are actively being stabilized and wired into the command plane.
> * Certain declared commands, modules, and configurations may evolve or undergo refactoring between milestone snapshots. Please refer to [TASK.md](TASK.md) and the [ADRs](docs/adr/) for active tracking.

---

## 🧭 Overview

**ClauseOS** is a bare-metal, self-contained operating system environment architecture designed to execute directly on the host machine while operating entirely within a hermetically confined profile directory (`.home/`). By redirecting `$HOME`, `$USERPROFILE`, and standard OS directory structures strictly into this localized root, ClauseOS eliminates host-level package managers, path pollution, global registry tampering, and configuration drift.

ClauseOS functions as an **Air-Gapped Seed Node**: a mobile command center capable of operating completely offline, self-bootstrapping isolated developer toolchains and specialized neural runtimes, bursting infrastructure into remote clouds via Pulumi, and cleanly detaching while cloud clusters continue autonomous operations.

Unlike virtual machines or Docker containers, ClauseOS introduces **zero hypervisor overhead** for local tools and grants applications unhindered, direct bare-metal access to hardware acceleration pipelines (NVIDIA CUDA, AMD ROCm, Intel XPU, and Apple Silicon MPS).

---

## 🏛️ Core Architectural Pillars

### 1. 🛡️ True Bare-Metal Hermetic Confinement
- **Immutable State Root (`.home/`):** All configurations, state stores, caches, models, and application data reside inside `CLAUSE_PROJECT_ROOT/.home`.
- **Zero Global Pollution:** Deleting `.home/` completely resets the environment to a pristine state without leaving residual files, PATH edits, or registry entries on the host machine.
- **Automated Hermeticity Assertions:** Continuous CI/CD testing (`tests/system/test_hermeticity.nu`) guarantees zero host path leakage or shell delimiter bleeding.

### 2. ⚙️ Two-Tier Orchestration Model (`mise` + `renv`)
- **Stage 1 & 2 (Base Tools & Cluster Engines):** Managed via `mise` (`.mise.toml`), provisioning core developer runtimes (`uv`, `just`, `git`, `nu`, `pulumi`) alongside HashiStack orchestrators (`nomad`, `consul`, `vault`, `packer`, `boundary`) and BEAM runtimes (`erlang`, `gleam`, `rebar3`).
- **Stage 3 (`renv` Application Layer):** Custom, isolated runtime environments provisioned on-demand via standalone `uv` into dedicated virtual environments (`apps/<name>/venv`), each with an independent CPython installation and zero cross-package contamination.

### 3. 🧠 Unified Ecosystem Model Storage (`HF_HOME`)
- Consolidates all AI checkpoints, LoRAs, UNet backbones, and GGUF quantizations into a single shared root (`.home/.local/share/models`).
- Automatically maps ComfyUI via `extra_model_paths.yaml` directly to the shared Hugging Face cache, eliminating redundant multi-gigabyte weight downloads between Unsloth, ComfyUI, Lemonade, and FastFlowLM.

### 4. 📦 Cross-Platform Micro-Virtualization (`cx vm`)
- Unified, disposable micro-instance engine running Linux-exclusive workloads (e.g., bare-metal Kubernetes/k3s, systemd daemons, eBPF probes) without privileged host daemons.
- Dynamically dispatches to **WSL2** on Windows (rootfs tarball imports confined to `.home/`) and **Lima (`limactl`)** on macOS/Linux with native multi-distro support (Alpine, Ubuntu, Debian).

### 5. 🤖 Autonomous Virtual Enterprise
- Built-in multi-agent corporate hierarchy (Board of Directors, Executive Leadership, Operational Departments) governed by `constitution.toml`.
- Autonomous agents leverage local neural coprocessors, execute batch tasks via Nomad `raw_exec` with full repo write privileges, and collaborate through an embedded Portable VS Code command harness.
- **Dual-Plane Execution & Closed-World Grounding:** Conversational chat handles intent and steering in the UI, while critical operations run non-conversationally via Nomad `raw_exec` batch jobs with strict exit-code gates.
- **Two-View Model (Contained SLMs vs. Saturated Generalists):** Upstream models handle intent shaping; worker agents utilize 1B–7B parameter models distilled and fine-tuned locally with Unsloth on verified ADRs, schemas, and test vectors, removing latent representations of evasion or hallucination.
- **Adversarial Gatekeeping:** Verbal completion claims are treated as unverified; supervising agents execute automated validation guardrails (git diff file bounds, hermetic test runs, schema validation) before Vault grants dynamic merge tokens.

### 6. 🌐 Distributed BEAM Backplane & Bare Metal as a Service (MaaS)
- **Gleam Orchestrator Core:** Positions Erlang/OTP and Gleam as the distributed cluster backplane, using soft real-time supervision trees to isolate node failures and telemetry without an etcd consensus bottleneck.
- **Nomad Execution with Ephemeral K8s:** Nomad manages bare-metal binaries and GPU jobs; Kubernetes (k3s) is treated as an optional guest target rather than the platform's control plane.
- **Zero-Touch Netboot Provisioning:** Integrates Pixiecore for API-driven iPXE bare-metal booting against Consul inventories, consuming in-memory golden rootfs images generated via Packer.
- **Programmatic IaC via Pulumi:** Replaces static HCL Terraform workflows with the Pulumi Automation API to manage networking, cloud bursting, and service state directly in code.

### 7. 🧬 Seax (`.cx`) Transmedia Language & Multi-Target Transpiler
- **Dart-Inspired Ergonomics:** Object-oriented class and interface syntax engineered in Rust using Pratt parsing and Thorsten Ball's compiler construction methodology.
- **Native Transmedia & Actor Keywords:** First-class syntax for media routing (`audio`, `video`, `midi`, `ndi`, `osc`, `smpte`, `dante`) and distributed agents (`agent`, `actor`, `telcom`, `container`, `process`, `broadcast`).
- **Monkey X Transpiler Architecture:** Lowers code directly to target-native representations without VM emulation (`target: beam` to Core Erlang / BEAM bytecode; `target: native-dsp` to C++20 / Rust NIFs; `target: client` to TypeScript / Wasm).
- **Agent is a Directory Pattern:** Packages agents and complete departments as self-contained directories containing the entrypoint (`agent.cx`), sub-agents (`team/`), capabilities (`skills/`), embedded MCP servers (`mcp/`), and target manifests (`package.seax`).

### 8. 🔗 RinG (Rust-in-Gleam) Integration Bridge
- Inspired by Rinf (Rust in Flutter), RinG code-generates strongly typed messaging channels between Rust and Gleam.
- Protects the BEAM scheduler by routing lightweight operations to immediate NIFs while offloading heavy DSP buffers, tensor routines, and file I/O to `DirtyCpu`/`DirtyIo` schedulers or ports.
- Wraps native Rust worker threads directly in supervised `gleam_otp` actors.

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
| **Micro-Hypervisor** | `cx vm` (WSL2 / Lima) | `.home/.../vms/` | Disposable Linux micro-instances for k3s & Linux-only daemons |
| **AI Fine-Tuning Engine**| Unsloth | `.home/.../apps/unsloth/` | Hardware-accelerated LLM parameter-efficient training & SLM distillation |
| **Neural Studio** | ComfyUI | `.home/.../apps/comfyui/` | Node-based diffusion model inference & visual studio |
| **Neural Coprocessors** | Lemonade / FastFlowLM | `.home/.../apps/lemonade/` | Embedded local LLM inference daemons & background agents |
| **Window Manager / UI** | Portable VS Code | `.home/.../apps/vscode/` | Primary graphical cockpit & agent host harness |
| **Distributed Backplane**| Erlang (BEAM) / Gleam | `.home/.../mise/installs/erlang` | Fault-tolerant distributed actor subsystem & orchestrator core |
| **Transmedia Language** | Seax (`seaxc`) | `.home/.../bin/seaxc` | Multi-target carrier language compiler (BEAM, C++, Wasm) |
| **Native Bridge** | RinG (Rust-in-Gleam) | `.home/.../bin/ring` | Type-safe code generator & dirty-scheduler FFI bridge |
| **Infra Kernel** | Pulumi CLI | `.home/.../apps/pulumi/` | Multi-cloud resource orchestration & programmatic Automation API |
| **Workload Scheduler** | HashiCorp Nomad | `.home/.../bin/nomad` | Distributed job & container orchestrator (`raw_exec`) |
| **Service Registry** | HashiCorp Consul | `.home/.../bin/consul` | Service discovery, mesh DNS, & Raft consensus |
| **Secrets Engine** | HashiCorp Vault | `.home/.../bin/vault` | Cryptographic key storage, leased tokens, & identity management |
| **MaaS Boot Engine** | Pixiecore | `.home/.../bin/pixiecore` | API-driven DHCP/TFTP/HTTP iPXE netboot runner |
| **Golden Image Builder** | HashiCorp Packer | `.home/.../bin/packer` | Deterministic in-memory micro-distro image compiler |
| **Zero-Trust Access** | HashiCorp Boundary | `.home/.../bin/boundary` | Identity-based user and agent access gateway |

---

## 📂 Canonical Directory Hierarchy

ClauseOS maps platform-specific conventions directly into the `.home/` sandbox:

```text
CLAUSE_PROJECT_ROOT/
├── .enterprise/                          # Virtual Enterprise Configuration Root
│   ├── board/                            # Board of Directors & constraints (constitution.toml)
│   ├── executive/                        # C-Suite agent schemas (CEO, CTO, CPO)
│   ├── departments/                      # Operational departments (Engineering, Security, SRE, QA)
│   ├── skills/                           # Modular CLI skills & toolsets (git-ops, test-runner)
│   └── plugins/                          # Dynamic reasoning extensions for agent harness
├── .home/                                # Hermetic Root ($HOME & $USERPROFILE)
│   ├── AppData/Local/Programs/           # [Windows] Binaries, apps, and logs
│   │   ├── bin/                          # Unified Stage 0/1 binaries & Mise shims
│   │   ├── apps/                         # Standalone 'renv' deployments (unsloth, comfyui, vscode)
│   │   ├── vms/                          # Confined WSL2 Virtual Hard Disks (ext4.vhdx)
│   │   └── logs/                         # Bootstrap & system execution logs
│   ├── .local/                           # [POSIX] Linux / macOS Application & Binary Root
│   │   ├── bin/                          # Unified binaries & shims
│   │   ├── apps/                         # Standalone 'renv' applications
│   │   ├── share/                        # Persistent application data (Mise, Nomad, Consul, Vault)
│   │   │   ├── models/                   # Unified Model Hub ($HF_HOME)
│   │   │   │   ├── hub/                  # Shared Hugging Face weights, LoRAs, and checkpoints
│   │   │   │   └── torch/                # Torch hub cache
│   │   │   └── vms/                      # Confined Lima micro-instances ($LIMA_HOME)
│   │   └── logs/                         # Bootstrap & execution logs
│   ├── .config/                          # [POSIX] XDG Config Home (Mise config, etc.)
│   ├── .cache/                           # Cache root (uv cache, vms/images rootfs cache)
│   ├── .ssh/                             # Confined SSH client configuration (config, known_hosts)
│   └── .gitconfig                        # Isolated Git user identity file
├── compiler/                             # Seax Transpiler Core (Rust)
│   └── seaxc/                            # Lexer, Pratt parser, IR, and target code generators
├── docs/                                 # Documentation & architecture records
│   └── adr/                              # Architecture Decision Records (ADRs)
├── ops/                                  # Infrastructure as Code & Orchestration
│   ├── config/                           # Nomad, Consul, and Vault HCL configs
│   ├── jobs/                             # Nomad job definitions (agent workers, batch runs, k3s)
│   ├── packer/                           # Packer templates for in-memory golden rootfs images
│   └── stacks/                           # Pulumi Cloud Infrastructure definitions
├── packages/                             # Custom internal packages & language extensions
├── projects/                             # User projects & workspace repositories
├── scripts/                              # Canonical automation scripts
│   ├── cli/                              # Userland CLI utilities & interactive environments
│   │   ├── nu/                           # Nushell modules (vm.nu, coprocessor.nu, config.nu, identity.nu)
│   │   └── pwsh/                         # PowerShell tooling
│   │       ├── installers/               # Stage 1 pre-Mise bootstrap installers
│   │       └── renv/                     # Stage 3 post-Mise runtime environment recipes
│   └── core/                             # Microkernel bootloader primitives
│       └── boot.ps1                      # Microkernel boot engine
├── services/                             # Core distributed system daemons
│   └── orchestrator/                     # Gleam/OTP cluster orchestrator application
├── tests/                                # Test harness suites
│   └── system/                           # Automated hermeticity and stage verification suites
├── tools/                                # Internal developer tool suites
│   └── ring/                             # RinG (Rust-in-Gleam) schema & code generator
├── .clause.toml                          # Central OS manifest & application toggle declarations
├── .mise.toml                            # Toolchain dependency & version manifest
├── justfile                              # Operational task commands
├── cx.bat                                # Windows Entrypoint Trampoline
├── cx.ps1                                # PowerShell Entrypoint Trampoline
└── cx.sh                                 # POSIX (Linux/macOS) Entrypoint Trampoline
```

---

## 🧠 Unified Model Cache & AI Storage

All AI workloads share a single, zero-duplication model cache rooted in `$HF_HOME`:

```text
.home/.local/share/models/
├── hub/
│   ├── models--unsloth--Qwen2.5-Coder-7B-Instruct/   ◄── Shared by Unsloth & Coprocessor
│   ├── models--black-forest-labs--FLUX.1-schnell/    ◄── Read by ComfyUI via extra_model_paths.yaml
│   └── models--bartowski--Llama-3.2-3B-GGUF/         ◄── FastFlowLM / Lemonade Agent Daemon
└── torch/                                             ◄── Torchvision & Torch Hub weights
```

- **Zero Duplication:** Unsloth fine-tunes weights directly against the same Hugging Face cache that ComfyUI queries for image generation and the agent daemons read for inference.
- **Hermetic Portability:** Backing up or moving `.home/.local/share/models` preserves the complete weights library without touching host OS directories.

---

## 📦 Cross-Platform Micro-Virtualization (`cx vm`)

For services requiring a full Linux kernel (such as lightweight Kubernetes via `k3s`, systemd services, or container daemons), ClauseOS exposes the unified `cx vm` subsystem:

```text
                               ┌─────────────────┐
                               │     cx vm       │
                               └────────┬────────┘
                                        │
                 ┌──────────────────────┴──────────────────────┐
                 ▼                                             ▼
         [Host == Windows]                             [Host == macOS / Linux]
                 │                                             │
          WSL2 Driver                                     Lima Driver
       (wsl.exe --import)                              (limactl start)
                 │                                             │
    Confined: .home/.../vms/                      Confined: $LIMA_HOME (.home/.../vms/)
  Distros: Alpine, Ubuntu, Debian               Distros: Alpine, Ubuntu, Debian
```

```nushell
# Launch a featherweight Alpine instance in ~1 second
cx vm launch k3s-node --distro alpine

# Execute commands directly inside the micro-instance
cx vm exec k3s-node -- uname -a

# Open an interactive shell
cx vm shell k3s-node

# Cleanly purge the VM and wipe all state
cx vm purge k3s-node
```

---

## 🤖 Autonomous Virtual Enterprise

ClauseOS includes an enterprise agent harness designed to run autonomous developer and operational teams directly inside the workspace:

```text
.enterprise/
├── board/                              # Governance & constraints (constitution.toml)
├── executive/
│   ├── ceo_agent                       # Strategic roadmap & issue dispatching
│   ├── cto_agent                       # Architectural integrity, ADR enforcement, code audits
│   └── cpo_agent                       # Feature delivery & developer UX tracking
├── departments/
│   ├── engineering/                    # Full repo write access (feature branches, test suites)
│   ├── security_audit/                 # Static analysis, dependency audits, secret scanning
│   ├── site_reliability/              # Nomad workload monitoring & Consul mesh health
│   └── documentation_qa/               # ADR authoring & documentation sync
└── skills/                             # Modular CLI toolsets (git-ops, test-runner, adr-writer)
```

- **Write-Access Guardrails:** Agents run via Nomad `raw_exec` tasks with credentials leased through Vault. Code modifications occur on isolated feature branches and require green passes from `just test-hermeticity` before pull requests are finalized.
- **Portable Cockpit:** Portable VS Code runs natively within the profile, bound directly to the local coprocessor (`http://127.0.0.1:8000/v1`) for local code intelligence.

---

## 🌐 BEAM Distributed Backplane & Gleam Orchestration

ClauseOS departs from traditional infrastructure stacks by positioning the **BEAM VM** as the primary distributed backplane and **Gleam** as the core orchestration language:

- **Soft Real-Time OTP Actors:** Cluster membership, node telemetry, and agent mailboxes are modeled as typed Gleam OTP actors (`gleam_otp`). Failure in a worker node or hardware process is isolated to its supervision tree branch without triggering global cluster churn.
- **Nomad Workload Scheduler:** Workloads are dispatched to Nomad via typed Gleam HTTP clients. Bare-metal binaries, local GPU models, and containerized micro-services execute via Nomad's `raw_exec` and container drivers.
- **Bare Metal as a Service (Pixiecore & iPXE):** The Gleam orchestrator coordinates with Pixiecore to netboot unprovisioned physical metal directly into memory using Packer-generated rootfs tarballs, automatically admitting machines into the Consul mesh.
- **Ephemeral Kubernetes (k3s):** Kubernetes is scheduled as a guest workload on Nomad inside disposable micro-instances (`cx vm`) only when tenants require standard K8s manifests.

---

## 🧬 Seax Carrier Language & Multi-Target Transpiler

**Seax** (`.cx`) is a carrier-class systems programming language designed for transmedia operations, autonomous agents, and real-time hardware orchestration:

- **Dart-Inspired Syntax:** Object-oriented class and interface ergonomics inspired by Dart and C#, with dependency injection and lifecycle hooks influenced by Laravel and Fowler's enterprise patterns.
- **Transmedia & Actor Keywords:** First-class language keywords for media protocols (`audio`, `video`, `midi`, `ndi`, `osc`, `smpte`, `dante`) and distributed agents (`agent`, `actor`, `telcom`, `broadcast`, `container`, `process`).
- **Monkey X Multi-Target Transpiler:** The Rust-based compiler (`seaxc`) lowers code directly to the optimal target platform without virtual-machine emulation:
  - `target: beam` $\rightarrow$ Compiles to Core Erlang AST and `.beam` bytecode for distributed cluster orchestration.
  - `target: native-dsp` $\rightarrow$ Compiles to optimized C++20 / Rust NIF routines linked with JUCE or native hardware SDKs.
  - `target: client` $\rightarrow$ Compiles to TypeScript and WebAssembly for interactive agent dashboards and web control planes.
- **Agent-as-a-Folder Architecture:** A complete agent or operational department is packaged as an isolated directory containing its coordinator (`agent.cx`), sub-agents (`team/`), capabilities (`skills/`), embedded MCP servers (`mcp/`), and target manifest (`package.seax`).

---

## 🔗 RinG: Rust-in-Gleam Native Bridge

**RinG** provides high-performance, type-safe interoperability between Rust algorithms and the Gleam/BEAM runtime, inspired by Rinf (Rust in Flutter):

- **Automated Code Generation:** Compiles shared contract schemas into Gleam type definitions and matching Rust FFI handlers, eliminating manual Erlang term format marshalling.
- **Scheduler Safety:** Automatically routes fast, non-blocking calls directly to Rustler NIFs, while steering heavy CPU tasks, SIMD processing, and streaming media buffers to BEAM `DirtyCpu`/`DirtyIo` schedulers to prevent scheduler poisoning.
- **OTP Actors:** Wraps native Rust worker threads as standard `gleam_otp` supervised actors with typed mailboxes.

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

- **NVIDIA CUDA:** Probes driver version via `nvidia-smi` and maps to `cu124`, `cu126`, `cu128`, or `cu130`.
- **AMD ROCm (Linux):** Probes `/dev/kfd` and `rocminfo`, targeting `https://download.pytorch.org/whl/rocm7.2`.
- **AMD ROCm (Windows):** Queries `Win32_VideoController` and configures AMD multi-architecture wheels (`torch[device-all]==2.13.0+rocm10.0.0`).
- **Intel Arc (XPU):** Detects Arc GPUs and binds `https://download.pytorch.org/whl/xpu`.
- **Apple Silicon (macOS `arm64`):** Leverages native Apple Metal Performance Shaders (`mps`).
- **macOS Intel (`x86_64`):** Gracefully falls back to CPU execution and automatically filters out unsupported architecture wheels (e.g. `comfy-angle`) to avoid dependency resolution errors.

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

### 3. Launch Orchestration & AI Workloads

```nushell
# Start local HashiCorp Nomad dev cluster
nomad agent -dev -config ops/config/nomad.hcl

# Launch local Neural Coprocessor Daemon
coprocessor start --engine lemonade --port 8000

# Launch ComfyUI Studio
comfyui --listen 127.0.0.1 --port 8188

# Launch Unsloth Fine-Tuning CLI
unsloth --help
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

## 💼 Open-Core & Monetization Strategy

ClauseOS strictly adheres to an unconstrained, developer-first open-core model:

- **Open-Source Base Substrate (100% Free & Unrestricted):**
  * Complete hermetic single-driver OS environment (`.home/` confinement).
  * Unlimited local node orchestration, clustering (Nomad/Consul/Vault/Boundary), and cloud bursting via Pulumi.
  * BEAM/Gleam distributed backplane and Pixiecore bare-metal provisioning (MaaS).
  * Dynamic 5-way GPU auto-detection and cross-platform virtualization (`cx vm`).
  * Seax compiler toolchain and folder-based agent development model.
  * Base Virtual Enterprise agent harness, skill runner, and portable editor cockpit.
- **Commercial Tier (Industry Adaptation & Enterprise Blueprints):**
  * **Regulated Industry Packs:** Pre-configured Virtual Enterprise cartridges for HIPAA Healthcare, FINRA/SEC FinTech, and Defense air-gapped environments.
  * **Enterprise Compliance & Governance:** Cryptographic audit trails, Open Policy Agent (OPA) agent guardrails, and automated board-level risk controls.
  * **Legacy Enterprise Connectors:** Turnkey bridges to SAP, Oracle, Epic, and corporate identity providers.

---

## 📚 Architecture Decision Records (ADRs)

Key architectural decisions are documented under `docs/adr/`:

- [**ADR 0001**: Hermetic State Confinement and Canonical Directory Hierarchy](docs/adr/0001-hermetic-state-confinement-and-canonical-directory-hierarchy.md)
- [**ADR 0002**: Two-Tier Toolchain Orchestration (`mise` and `renv`)](docs/adr/0002-two-tier-toolchain-orchestration-mise-and-renv.md)
- [**ADR 0003**: Dynamic Multi-Vendor Hardware Acceleration Matrix](docs/adr/0003-dynamic-multi-vendor-hardware-acceleration-matrix.md)
- [**ADR 0004**: Cross-Shell Environment and PATH Delimiter Canonicalization](docs/adr/0004-cross-shell-environment-and-path-delimiter-canonicalization.md)
- [**ADR 0005**: Unified Model Storage & Ecosystem Cache Projection](docs/adr/0005-unified-model-storage-hub.md)
- [**ADR 0006**: Cross-Platform Micro-Instance Virtualization (`cx vm`)](docs/adr/0006-micro-instance-virtualization.md)
- [**ADR 0007**: Open-Core Substrate vs. Industry Adaptation Commercialization](docs/adr/0007-open-core-and-monetization.md)
- [**ADR 0008**: Virtual Enterprise Organizational Hierarchy & Agent Governance](docs/adr/0008-virtual-enterprise-agent-hierarchy.md)
- [**ADR 0009**: VS Code Agent Host, Extensibility Plugins, and Skill Toolsets](docs/adr/0009-agent-skills-plugins-vscode-harness.md)
- [**ADR 0010**: Distributed BEAM Backplane, Gleam Orchestration, Nomad Scheduling, and MaaS](docs/adr/0010-beam-orchestrator-nomad-scheduler-maas.md)
- [**ADR 0011**: Seax Programming Language, Multi-Target Transpiler, and Agent Directory Pattern](docs/adr/0011-seax-language-transpiler-agent-directory.md)
- [**ADR 0012**: RinG (Rust-in-Gleam) Type-Safe Native Integration Bridge](docs/adr/0012-ring-rust-in-gleam-bridge.md)
- [**ADR 0013**: Curated Domain SLMs vs. Saturated Generalist Models](docs/adr/0013-curated-domain-slms-vs-saturated-generalists.md)

---

<div align="center">

Built With ❤️ By Vieo

</div>