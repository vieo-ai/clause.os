# ClauseOS (`clause.os`)

> **Autonomous, Hermetic Single-Driver OS Environment & Air-Gapped Cloud Bursting Platform**

ClauseOS is a cross-platform, self-contained operating system environment architecture designed to operate entirely within a confined user profile directory (`/clause` or `M:\clause`). By treating the workspace root as `$HOME` and `$USERPROFILE`, ClauseOS achieves total isolation from host-level package managers, path pollution, and host system state.

It functions as an **Air-Gapped Seed Node**: a mobile command center capable of operating completely offline, bootstrapping local environments, bursting infrastructure into remote clouds via Pulumi, and gracefully disconnecting to leave cloud clusters running autonomously.

---

## Key Features

* **Confined Profile Architecture:** Overrides `$HOME`, `$USERPROFILE`, and standard XDG directory paths (`.config`, `.local`, `.cache`) strictly to the repository root[cite: 1].
* **Single-Driver Model (Mise):** Eliminates Scoop and Homebrew host dependencies[cite: 1]. Utilizes `mise` backends (`native`, `github:`, `aqua:`, `vfox:`) to fetch, lock, and manage all binary toolchains and runtimes[cite: 1].
* **Unified Binary Path:** All executable shims and pre-seeded binaries route through `.local/bin`, simplifying `$PATH` management down to a single directory[cite: 1].
* **Two-Command Bootloader:** Bootstraps the microkernel engine and hydrates the complete toolchain in two simple steps (`./clause` $\rightarrow$ `clause pkg install`)[cite: 1].
* **Portable IDE & Neural Daemons:** Embedded portable editor (VS Code) and local LLM inference runtimes (`lemonade`, `fastflowlm`) bound strictly within the local profile[cite: 1].
* **Air-Gapped Cloud Bursting:** Native orchestration stack (Erlang/Gleam, Pulumi, Nomad, Consul, Vault) allowing local seed nodes to provision remote infrastructure, promote cluster quorum, and detach cleanly[cite: 1].

---

## Operating System Primitives Mapping

ClauseOS maps userland binaries and services directly into functional OS system primitives[cite: 1]:

| OS Primitive | Clause Component | Hermetic Location | Function |
| :--- | :--- | :--- | :--- |
| **Microkernel / Exec** | `clause.ps1` / `clause.sh` | `/clause/clause.ps1` | Stage 0 bootloader & environment isolator[cite: 1] |
| **Shell & Init (PID 1)** | Nushell (`nu`) | `.local/bin/nu` | Interactive command processor & process supervisor[cite: 1] |
| **Driver & HAL** | Mise | `.local/bin/mise` | Unified toolchain driver & dynamic runtime loader[cite: 1] |
| **Task Scheduler** | Just | `.local/bin/just` | Task runner for system workflows & build targets[cite: 1] |
| **Window Manager / UI** | Portable VS Code | `.local/app/vscode/` | Primary graphical development interface[cite: 1] |
| **Neural Coprocessors** | Lemonade / FastFlowLM | `.local/app/` | Embedded LLM inference daemons & AI acceleration[cite: 1] |
| **Concurrency Engine** | Erlang (BEAM) / Gleam | `.cache/toolchain/mise/` | Fault-tolerant distributed actor subsystem[cite: 1] |
| **Infra Kernel** | Pulumi CLI | `.local/bin/pulumi` | Cloud resource provisioning engine[cite: 1] |
| **Workload Scheduler** | HashiCorp Nomad | `.local/bin/nomad` | Distributed job & container orchestrator[cite: 1] |
| **Service Registry** | HashiCorp Consul | `.local/bin/consul` | Service discovery, DNS, & Raft consensus[cite: 1] |
| **Secrets Engine** | HashiCorp Vault | `.local/bin/vault` | Cryptographic key storage & identity management[cite: 1] |

---

## Directory Structure

```text
/clause/                                # System Confined Profile Root ($HOME / $USERPROFILE)
├── .config/                            # XDG Configuration Home ($XDG_CONFIG_HOME)
│   ├── nushell/                        # Nushell configuration files (env.nu, config.nu)
│   ├── pwsh/                           # PowerShell profile settings
│   └── git/                            # Isolated Git configurations
├── .local/                             # XDG Data & Binary Home ($XDG_DATA_HOME)
│   ├── bin/                            # Unified binary directory & Mise shims
│   ├── app/                            # Portable applications (vscode, lemonade, fastflowlm)
│   └── share/                          # Persistent application data & database files
├── .cache/                             # XDG Cache Home ($XDG_CACHE_HOME)
│   ├── toolchain/                      # Managed Mise runtimes & tool installations
│   └── m-cache/                        # Short-path download cache
├── .ssh/                               # Hermetic SSH profiles, keys, and known_hosts
├── ops/                                # Infrastructure code (Pulumi stack definitions)
├── packages/                           # Internal custom packages & modules
├── projects/                           # Isolated local user workspace
├── scripts/                            # System scripts & Nushell router modules
├── clause.ps1                          # Windows Stage 0 Bootloader Trampoline
├── clause.sh                           # POSIX Stage 0 Bootloader Trampoline
├── .mise.toml                          # Central System Toolchain & Runtime Specification
└── justfile                            # System operational task definitions
```

# Quick Start

## 1. Boot into ClauseOS

Executing the Stage 0 bootloader confines the environment and boots directly into Nushell[cite: 1]:

**Windows (PowerShell):**
```powershell
.\clause.ps1
```

**POSIX (Linux / macOS):**
```bash
./clause.sh
```

## 2. Hydrate the Environment

Inside the Nushell shell, execute the system package router to download and link all toolchains declared in `.mise.toml`[cite: 1]:

```nushell
clause pkg install
```

---

# Cloud Bursting & Detachment Flow

ClauseOS allows you to provision remote cloud infrastructure from your local seed node, join the cluster, and detach cleanly[cite: 1]:

```bash
# 1. Spin up remote cloud nodes & join local Consul/Nomad cluster
clause cloud up

# 2. Sever local connection (Local node drains; Cloud cluster continues autonomously)
clause cloud detach
```