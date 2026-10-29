# ClauseOS Project Ledger & Architectural Milestones

## Overview

ClauseOS is a zero-overhead, bare-metal microkernel environment, distributed BEAM cloud OS, and transmedia agent workbench. It enforces deterministic, hermetic state isolation across Windows, Linux, and macOS without host pollution.

This ledger documents the chronological evolution of the system based on git commit history from repository creation to full green matrix cross-platform CI/CD status, followed by active and upcoming architectural phases.

---

## Chronological Commit History & Architectural Phases

### Phase 1: Inception & Core Scaffolding (Oct 19, 2026)
* **`559d454d`**: Initial repository commit.
* **`fb3ac8b3` – `adfc8725`**: Initial core manifests initialized (`.gitattributes`, `.gitconfig`, `.gitignore`, `.mise.toml`, `.clause.toml`, `apm.yml`, `justfile`).
* **`253d5229` – `fadde797`**: Bootstrap entry points introduced (`clause.bat`, `clause.ps1`, `clause.sh`, `install.bat`, `install.sh`, `start.bat`, `start.sh`) for provisioning PowerShell Core dynamically.
* **`41cca74f` – `ed9124fa`**: Initial GitHub Actions matrix established for cross-platform runner detection and validation.
* **`d04f9194` – `4726d4ed`**: Initial environment scripts added (`env.ps1`, `env.nu`, `env.sh`) establishing baseline variables.
* **`90843fca` – `92050c04`**: Windows profile confinement and cleanup to prevent OS dotfile leaks into host profile paths.
* **`0e159177` – `61ee92cd`**: Introduction of Universal Command Router, ASCII banner command, and Startup Verification Engine.
* **`e29e17d8` – `d131ecfc`**: Git subtree automation scripts for ecosystem dependencies (`cozystack`, `framework`, `glimr`, `hashistack`, `loom`, `lustre`, `plushie`, `shore`, `stacker`, `tauri`, `typhoon`, `upsonic`).
* **`5fb1c964` – `87ca9f15`**: Dynamic Nushell Mise activation overlay generation (`mise.nu`).

### Phase 2: Hermetic Isolation & Stage 0 Verification (Oct 20 – 21, 2026)
* **`638eab2d` – `849ae19c`**: System verification suites implemented in `run_all.nu`, establishing `test_stage0.nu`, `test_stage1.nu`, and baseline `test_hermeticity.nu`.
* **`a940bade`**: Updated hermeticity tests to assert `.local/bin` presence in `PATH`.
* **`658b1257` – `b6d20121`**: Standardization of entrypoint naming to `cx.bat`, `cx.ps1`, and `cx.sh`, aliasing `carrier` and `cx` to the microkernel bootloader.
* **`1f523da6`**: Unified entrypoint routing.

### Phase 3: Project Root Consolidation & Clean Architecture (Oct 22 – 24, 2026)
* **`26c0a28b` – `da01e74f`**: Git config global redirection (`.gitconfig` isolation at root) and `sync_jet.ps1` implementation.
* **`3c489de5` – `ea334a86`**: Restructuring of `.mise.toml` to support core language runtimes and toolchain finalization hooks.
* **`d25d29b8` – `328eb6d6`**: Removal of obsolete user directories from git tracking, enforcing all state to `.home/`.

### Phase 4: Canonical Script Hierarchy & Test Framework (Oct 26 – 27, 2026)
* **`6ddde493` – `a50143a7`**: Rewrite of `boot.ps1`, `env.nu`, `env.sh`, and `env.ps1` to canonical specification:
  * Windows NT path anchoring (`AppData\Local`, `AppData\Roaming`).
  * POSIX XDG path anchoring (`.local`, `.config`, `.cache`).
  * Universal `CLAUSE_PROJECT_ROOT` resolution via `FILE_PWD`.
* **`00d3267f` – `55692e5c`**: Environment testing harness added across all shell dialects (`run_tests.ps1`, `run_tests.nu`, `run_test.sh`).
* **`1b287dcb` – `cce4c743`**: Refactored Nushell handoff and diagnostic logging inside `boot.ps1`.
* **`5efd44d6` – `769c8d93`**: Comprehensive rewrite of `test_hermeticity.nu` and `test_stage0.nu` asserting strict confinement.
* **`872e5387` – `e910c210`**: Modularization of installer scripts into dedicated subdirectories.

### Phase 5: Renv Runtime Split & Pulumi Integration (Oct 27, 2026)
* **`876a9f3f` – `5cde151b`**: Addition of Pulumi infrastructure engine installer and binary path resolution.
* **`6a441003`**: Addition of Python and package runtimes to `.mise.toml`, seeding standalone `uv`.
* **`d42e0b46` & `ef1ab516`**: Creation of initial installer recipes for Unsloth AI Engine and ComfyUI.
* **`38808378`**: Relocation of application installers to `scripts/cli/pwsh/renv/` establishing the two-tier architecture.
* **`ae706f65` – `5cecce66`**: Integration of `unsloth/bin` into `.mise.toml` `_.path` and dispatching post-Mise runtime recipes in Stage 3.

### Phase 6: Directory Provisioning & Cache Hardening (Oct 28, 2026 - Early)
* **`09a4dd3be` – `e59cbc0a`**: Introduction and enforcement of `CLAUSE_CACHE_DIR` across Windows, Linux, and macOS.
* **`e7358ed8`**: Added fallback resolution for `uv` binary via direct bin, PATH, and Mise shims with diagnostic error logging.
* **`b4f405e3`**: Cleaned and re-created `CLAUSE_TEMP_DIR` on boot to prevent stale locks while ensuring directory existence for child scripts.
* **`8970e0fef` – `8a1381b6`**: Guaranteed existence of `CLAUSE_BIN_DIR` before PATH expansion.
* **`e6e0e0e4`**: Ensured `CLAUSE_TEMP_DIR` and `CLAUSE_CACHE_DIR` exist before Unsloth writes override files.

### Phase 7: Cross-Shell PATH & Nushell Delimiter Normalization (Oct 28, 2026 - Midday)
* **`a9f80ea0`**: Fixed `boot.ps1` Mise shim PATH injection to use platform-aware delimiters (`:` on POSIX, `;` on Windows), preventing delimiter bleed.
* **`26d47ba9` – `c4b2b397`**: Hardened Nushell `env.nu` and `test_hermeticity.nu` with defensive two-pass entry splitting across both `;` and `:`.
* **`0ee86088` – `501bafdb`**: Refined path expansion logic to handle macOS `/var` vs `/private/var` symlink canonicalization.
* **`3f588384`**: Streamlined Nushell `config.nu` to load `source ./mise.nu` via static parse-time relative resolution, removing parse-time variable errors and restoring `$env.config` processing.

### Phase 8: ComfyUI Hardware Matrix & macOS Intel Fix (Oct 28, 2026 - Afternoon)
* **`cb09ba0f` – `0b8bdb47`**: Registered ComfyUI in `.clause.toml` and added `comfyui/bin` to `.mise.toml` `_.path`.
* **`9db433a1` – `2e8e5150`**: Implemented `scripts/cli/pwsh/renv/installer_comfyui.ps1` with 5-way hardware acceleration and error logging.
* **`d452e807`**: Added conditional wheel requirement filter for macOS Intel (`x86_64`) runners to bypass `comfy-angle`, enabling 100% green CI/CD status across all platforms.

---

## Architectural Decision Records (ADRs)

| ADR | Title | Key Commits / Context | Status |
| :--- | :--- | :--- | :--- |
| [ADR 0001](docs/adr/0001-hermetic-state-confinement-and-canonical-directory-hierarchy.md) | Hermetic State Confinement and Canonical Directory Hierarchy | `6ddde493`, `872e5387`, `09a4dd3b`, `e59cbc0a` | Accepted |
| [ADR 0002](docs/adr/0002-two-tier-toolchain-orchestration-mise-and-renv.md) | Two-Tier Toolchain Orchestration (Mise + Renv) | `6a441003`, `38808378`, `5cecce66`, `e7358ed8` | Accepted |
| [ADR 0003](docs/adr/0003-dynamic-multi-vendor-hardware-acceleration-matrix.md) | Dynamic Multi-Vendor Hardware Acceleration Matrix | `d42e0b46`, `9db433a1`, `2e8e5150`, `d452e807` | Accepted |
| [ADR 0004](docs/adr/0004-cross-shell-environment-and-path-delimiter-canonicalization.md) | Cross-Shell Environment and PATH Delimiter Canonicalization | `a9f80ea0`, `26d47ba9`, `501bafdb`, `3f588384` | Accepted |
| [ADR 0005](docs/adr/0005-unified-model-storage-hub.md) | Unified Model Storage & Ecosystem Cache Projection | Stage 0/3 Path Exports, `HF_HOME` Anchoring | Accepted |
| [ADR 0006](docs/adr/0006-micro-instance-virtualization.md) | Cross-Platform Micro-Instance Virtualization (`cx vm`) | WSL2 / Lima Dynamic Hypervisor Dispatch | Accepted |
| [ADR 0007](docs/adr/0007-open-core-and-monetization.md) | Open-Core Substrate vs. Industry Adaptation Commercialization | Base Substrate vs. Enterprise Industry Packs | Accepted |
| [ADR 0008](docs/adr/0008-virtual-enterprise-agent-hierarchy.md) | Virtual Enterprise Governance, Adversarial Gates & Grounding | Board, Executive, Department Schemas, SSOT Guardrails | Accepted |
| [ADR 0009](docs/adr/0009-agent-skills-plugins-vscode-harness.md) | VS Code Agent Host, Extensibility Plugins, and Skill Toolsets | Portable VS Code, Plugin & Skill Routers | Accepted |
| [ADR 0010](docs/adr/0010-beam-orchestrator-nomad-scheduler-maas.md) | Distributed BEAM Backplane, Gleam Orchestration, Nomad Scheduling, and MaaS | BEAM/OTP Core, Nomad Scheduler, Pixiecore, Pulumi | Accepted |
| [ADR 0011](docs/adr/0011-seax-language-transpiler-agent-directory.md) | Seax Programming Language, Multi-Target Transpiler, and Agent Directory Pattern | Monkey X Transpiler Backend, Rust Compiler, Agent as Folder | Accepted |
| [ADR 0012](docs/adr/0012-ring-rust-in-gleam-bridge.md) | RinG (Rust-in-Gleam) Type-Safe Native Integration Bridge | Schema-Driven FFI, Dirty Scheduler Routing, Typed Actors | Accepted |
| [ADR 0013](docs/adr/0013-curated-domain-slms-vs-saturated-generalists.md) | Curated Domain SLMs vs. Saturated Generalist Models | Contained Task-Specific SLMs, Two-View Strategy, Zero-Evasion Weights | Accepted |

---

## Active Roadmap & Implementation Milestones

### Phase 9: Core Orchestration, Unified AI Storage & Bootloader Refactoring (Current Milestone: v0.1.5-dev)
- [ ] **Bootloader Restructuring & Root Cleanup**:
  - Relocate `boot.ps1` from workspace root to `scripts/core/boot.ps1`.
  - Update root trampolines (`cx.bat`, `cx.ps1`, `cx.sh`) to point directly to `scripts/core/boot.ps1`.
  - Audit `CLAUSE_PROJECT_ROOT` resolution in `scripts/core/boot.ps1` using parent traversal (`Resolve-Path ../..`).
- [ ] **HashiStack Toolchain Hydration**:
  - Register `nomad`, `consul`, `vault`, `packer`, and `boundary` in `.mise.toml`.
  - Verify executable shims populate `.home/.local/share/mise/shims` across platforms.
- [ ] **BEAM & Gleam Platform Toolchain**:
  - Register `erlang`, `gleam`, and `rebar3` in `.mise.toml`.
  - Validate clean hydration into `.home/.local/share/mise/shims`.
- [ ] **Hermetic Cluster Configuration Anchoring**:
  - Author `ops/config/nomad.hcl` (bound to `$env:CLAUSE_HOME/.local/share/nomad` with `raw_exec` enabled).
  - Author `ops/config/consul.hcl` (bound to `$env:CLAUSE_HOME/.local/share/consul` with UI enabled).
  - Author `ops/config/vault.hcl` (bound to `$env:CLAUSE_HOME/.local/share/vault` with local TCP listener).
- [ ] **Model Hub Unification**:
  - Export canonical `$env:HF_HOME`, `$env:HUGGINGFACE_HUB_CACHE`, `$env:TRANSFORMERS_CACHE`, and `$env:TORCH_HOME` across `env.ps1`, `env.nu`, and `env.sh`.
  - Update `installer_comfyui.ps1` to generate `extra_model_paths.yaml` bound to `$env:HF_HOME/hub`.
- [ ] **Hermetic Git & Identity Lock**:
  - Configure Stage 0 initialization of `.home/.ssh/config` and `.home/.gitconfig` with local credential routing.
  - Author `scripts/cli/nu/modules/identity.nu` (`cx identity {setup, import, new, show}`).
- [ ] **Headless Sanity Testing**:
  - Implement `tests/system/test_inference.nu` to validate device resolution without invoking interactive shells.

### Phase 10: Gleam Distributed Orchestrator, RinG Bridge & MaaS Pipeline
- [ ] **Gleam Orchestrator Core**:
  - Initialize `services/orchestrator/` with `gleam.toml` and OTP supervision tree.
  - Implement root application supervisor managing catalog discovery, workload dispatch, and netboot triggers.
- [ ] **RinG (Rust-in-Gleam) Integration Bridge**:
  - Scaffold `tools/ring/` code generator generating strongly typed Gleam types and matching Rustler FFI structs.
  - Implement scheduler routing allocating fast calls to immediate NIFs and heavy tasks to `DirtyCpu`/`DirtyIo`.
  - Wrap native Rust worker instances in typed `gleam_otp` actors.
- [ ] **Infrastructure Adapters**:
  - Author Gleam HTTP clients for Nomad job dispatch (`/v1/jobs`), Consul catalog sync, and Vault leased credentials.
- [ ] **Bare Metal as a Service (Pixiecore & iPXE)**:
  - Package Pixiecore binary as an embedded boot runner.
  - Author Gleam event listener coordinating API-driven iPXE boots against Consul machine inventories.
  - Author Packer templates in `ops/packer/` for memory-resident micro-distros with embedded Stage 0 trampolines.
- [ ] **Ephemeral Kubernetes (k3s) Guest Target**:
  - Author Nomad job specification to launch ephemeral k3s clusters inside micro-instances on demand.
- [ ] **Pulumi Automation Driver**:
  - Author `scripts/cli/nu/modules/infra.nu` bridging Pulumi Automation API execution.

### Phase 11: Seax Language Compiler Core (`seaxc`)
- [ ] **Compiler Scaffolding (Rust)**:
  - Initialize `compiler/seaxc/` Cargo workspace.
  - Port Pratt parser and lexer architecture following Thorsten Ball's mechanical compiler construction.
- [ ] **Lexer & Grammar Parser**:
  - Implement tokenizer supporting Dart-like OOP syntax, transmedia keywords (`audio`, `video`, `midi`, `ndi`, `osc`, `smpte`, `dante`), and infrastructure keywords (`agent`, `actor`, `telcom`, `container`, `process`, `broadcast`).
- [ ] **Intermediate Representation (Seax IR)**:
  - Author AST-to-IR lowering resolving actor mailboxes, ownership leases, and buffer lifecycle contracts.
- [ ] **Multi-Target Emitters (Monkey X Architecture)**:
  - `emit_beam`: Transpile Seax IR to Core Erlang AST and compile to `.beam` bytecode.
  - `emit_cpp`: Transpile real-time media buffer pipelines into high-performance C++20 / Rust NIF blocks.
  - `emit_ts`: Transpile agent control dashboards and MCP schemas into TypeScript / Wasm.
- [ ] **Agent-as-a-Folder Execution Model**:
  - Author directory packaging engine compiling self-contained agent folders (`agent.cx`, `team/`, `skills/`, `mcp/`, `package.seax`).
  - Wire CLI build command into Stage 2 router (`cx seax build <dir>`).

### Phase 12: Hermetic Micro-Instance Virtualization (`cx vm`)
- [ ] **Windows Driver (`wsl.exe`)**:
  - Implement import/export pipeline targeting `$env:CLAUSE_HOME/AppData/Local/Programs/vms/<name>/ext4.vhdx`.
  - Inject `/etc/wsl.conf` with systemd enabled and Windows path appending disabled.
- [ ] **POSIX Driver (`limactl`)**:
  - Implement wrapper routing with `$env:LIMA_HOME` bound to `$env:CLAUSE_HOME/.local/share/vms`.
- [ ] **CLI Module Integration**:
  - Author `scripts/cli/nu/modules/vm.nu` (`launch`, `exec`, `shell`, `list`, `stop`, `purge`).
  - Wire `vm` command tree into the Universal Command Router (`cx vm`).

### Phase 13: Virtual Enterprise Agent Hierarchy, Fine-Tuning & VS Code Host
- [ ] **Local Neural Coprocessor Supervisor**:
  - Implement Nushell module to manage background inference processes for Stage 0 Lemonade / FastFlowLM daemons (`http://127.0.0.1:8000/v1`).
- [ ] **Domain SLM Fine-Tuning Pipeline (Unsloth)**:
  - Curate golden training datasets composed strictly of repository ADRs, schema files, and test vectors.
  - Create distillation and quantization scripts to produce focused 1B–7B operational worker models directly into `$HF_HOME/hub`.
- [ ] **Governance & Closed-World Ground Schemas (`.enterprise/`)**:
  - Scaffold `.enterprise/board/constitution.toml` with immutable sandbox, closed-world ground checks, and spend boundaries.
  - Create executive role definitions (`ceo_agent`, `cto_agent`, `cpo_agent`) in `.enterprise/executive/`.
  - Scaffold operational departments (`engineering`, `security_audit`, `site_reliability`, `documentation_qa`) in `.enterprise/departments/`.
- [ ] **Nomad Write-Access Worker**:
  - Create `ops/jobs/repo_agent.nomad.hcl` executing under `raw_exec` with full `$env:CLAUSE_PROJECT_ROOT` write scope and branch isolation.
- [ ] **Adversarial Gatekeeper & Supervisory Audit**:
  - Implement supervisory check-mate validation ensuring worker PRs cite valid ADR/Schema keys and return exit code 0 on tests.
  - Wire Vault lease tokens to only unlock merge capabilities upon green assertion pass.
- [ ] **Compensation & Ledger Engine**:
  - Scaffold internal token/credit reward ledger compensating worker agents upon verified task completions and PR merges.
- [ ] **Skill Toolset Core (`.enterprise/skills/`)**:
  - Implement execution runner for modular skills (`git-ops`, `code-analysis`, `test-runner`, `adr-writer`).
- [ ] **Portable VS Code Control Plane**:
  - Confine user data and extension paths to `.home/.local/app/vscode/`.
  - Wire workspace extensions and telemetry settings to the local coprocessor and Nomad cluster.

### Phase 14: Release Promotion & Commercial Fork
- [ ] **Substrate Audit**: Full pass of `run_all.nu` hermeticity and orchestration tests on Windows, Linux, and macOS runners.
- [ ] **Version Promotion**: Bump `.clause.toml` to `0.1.5` and cut `v0.1.5` git tag (stripping `-dev` / milestone markers).
- [ ] **Publish Open Core**: Ship the unconstrained Apache 2.0 substrate.
- [ ] **Fork Commercial Track**: Initialize the enterprise repository for industry-specific compliance packs and connectors.