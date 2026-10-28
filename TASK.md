# ClauseOS Project Ledger & Architectural Milestones

## Overview

ClauseOS is a zero-overhead, bare-metal microkernel environment for AI workloads and developer tools. It enforces deterministic, hermetic state isolation across Windows, Linux, and macOS without relying on containers or virtual machines.

This ledger documents the chronological evolution of the system based on git commit history from repository creation to full green matrix cross-platform CI/CD status.

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

| ADR | Title | Key Commits | Status |
| :--- | :--- | :--- | :--- |
| [ADR 001](docs/adr/0001-hermetic-state-confinement-and-canonical-directory-hierarchy.md) | Hermetic State Confinement and Canonical Directory Hierarchy | `6ddde493`, `872e5387`, `09a4dd3b`, `e59cbc0a` | Accepted |
| [ADR 002](docs/adr/0002-two-tier-toolchain-orchestration-mise-and-renv.md) | Two-Tier Toolchain Orchestration (Mise + Renv) | `6a441003`, `38808378`, `5cecce66`, `e7358ed8` | Accepted |
| [ADR 003](docs/adr/0003-dynamic-multi-vendor-hardware-acceleration-matrix.md) | Dynamic Multi-Vendor Hardware Acceleration Matrix | `d42e0b46`, `9db433a1`, `2e8e5150`, `d452e807` | Accepted |
| [ADR 004](docs/adr/0004-cross-shell-environment-and-path-delimiter-canonicalization.md) | Cross-Shell Environment and PATH Delimiter Canonicalization | `a9f80ea0`, `26d47ba9`, `501bafdb`, `3f588384` | Accepted |

---

## Current Status & Next Actions

* **Current Status**: Complete bare-metal hermetic microkernel operational across Windows, Linux, and macOS. CI/CD test matrices passing 100% green with native Unsloth and ComfyUI runtime deployments.
* **Active Tasks**:
  1. Implement shared weight routing for ComfyUI and Unsloth via automated generation of `extra_model_paths.yaml`.
  2. Add automated inference sanity-check tests (`tests/system/test_inference.nu`) for headless GPU validation.