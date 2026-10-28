# ADR 001: Hermetic State Confinement and Canonical Directory Hierarchy

- **Status**: Accepted
- **Date**: 2026-10-28
- **Context**: ClauseOS Bootloader & Runtime Isolation

## Context and Problem Statement

Running complex developer tools, language runtimes, package managers, and AI inference engines across diverse host operating systems (Windows, Linux, macOS) typically results in host contamination. Standard tools pollute global paths (`~/.cache`, `~/.local`, `~/.config`, `%APPDATA%`, `%LOCALAPPDATA%`), collide with pre-existing user environments, and introduce non-deterministic state drift. Virtual machines and container solutions (Docker, WSL2) solve state isolation but incur steep hypervisor virtualization overhead, degrade host-native I/O, and introduce complex GPU passthrough friction across discrete hardware vendors (NVIDIA, AMD, Intel, Apple).

ClauseOS requires a bare-metal, zero-overhead environment model that guarantees deterministic execution across Windows, Linux, and macOS without mutating host configuration or requiring elevated administrative privileges.

## Decision Drivers

- **Zero Host Contamination**: Guarantee that all binaries, configurations, caches, virtual environments, and temporary artifacts remain confined to the project root.
- **Cross-Platform Uniformity**: Maintain a 1:1 conceptual mapping between Windows NT path paradigms and POSIX/XDG standards.
- **Bare-Metal GPU Access**: Avoid hypervisor layers to preserve native hardware compute and direct driver interaction.
- **Defensive Idempotency**: Provide deterministic startup execution across PowerShell, Nushell, and POSIX shells.

## Considered Options

1. **Host-Level Global Installation with Namespace Prefixes**: Install tools directly into the host user profile under unique subfolders.
2. **Container/Virtual Machine Encapsulation (Docker / Podman / WSL2)**: Enforce boundaries via containerization.
3. **Hermetic Root Confinement (`.home/`) with Canonical Environment Anchors**: Re-anchor system identity and path variables to a localized sandbox.

## Decision Outcome

Chosen Option: **Option 3 (Hermetic Root Confinement with Canonical Anchors)**.

All subshells and runtime processes launched by ClauseOS operate with their core user identity and directory redirection variables mapped exclusively inside `CLAUSE_PROJECT_ROOT/.home`.

### Directory Layout & Variable Contracts

#### Common Base Anchors
- `CLAUSE_PROJECT_ROOT`: Absolute, fully resolved root path of the repository.
- `CLAUSE_HOME`: Path to `$CLAUSE_PROJECT_ROOT/.home`.
- `HOME`: Anchored directly to `$CLAUSE_HOME`.
- `USERPROFILE`: Anchored directly to `$CLAUSE_HOME`.

#### Windows NT Hierarchy (`$IsOSWindows`)
- `LOCALAPPDATA` $\rightarrow$ `$CLAUSE_HOME\AppData\Local`
- `APPDATA` $\rightarrow$ `$CLAUSE_HOME\AppData\Roaming`
- `CLAUSE_BIN_DIR` $\rightarrow$ `$LOCALAPPDATA\Programs\bin`
- `CLAUSE_APPS_DIR` $\rightarrow$ `$LOCALAPPDATA\Programs\apps`
- `CLAUSE_CACHE_DIR` $\rightarrow$ `$LOCALAPPDATA\cache`
- `CLAUSE_TEMP_DIR` $\rightarrow$ `$LOCALAPPDATA\Temp`
- `CLAUSE_LOGS_DIR` $\rightarrow$ `$LOCALAPPDATA\Programs\logs`
- `MISE_DATA_DIR` $\rightarrow$ `$LOCALAPPDATA\mise`
- `MISE_CONFIG_DIR` $\rightarrow$ `$APPDATA\mise`
- `MISE_STATE_DIR` $\rightarrow$ `$LOCALAPPDATA\mise\state`
- `MISE_CACHE_DIR` $\rightarrow$ `$LOCALAPPDATA\mise\cache`

#### POSIX XDG Hierarchy (Linux & macOS)
- `XDG_CONFIG_HOME` $\rightarrow$ `$CLAUSE_HOME/.config`
- `XDG_DATA_HOME` $\rightarrow$ `$CLAUSE_HOME/.local/share`
- `XDG_STATE_HOME` $\rightarrow$ `$CLAUSE_HOME/.local/state`
- `XDG_CACHE_HOME` $\rightarrow$ `$CLAUSE_HOME/.cache`
- `CLAUSE_BIN_DIR` $\rightarrow$ `$CLAUSE_HOME/.local/bin`
- `CLAUSE_APPS_DIR` $\rightarrow$ `$CLAUSE_HOME/.local/apps`
- `CLAUSE_CACHE_DIR` $\rightarrow$ `$XDG_CACHE_HOME`
- `CLAUSE_TEMP_DIR` $\rightarrow$ `$XDG_CACHE_HOME/tmp_bootstrap`
- `CLAUSE_LOGS_DIR` $\rightarrow$ `$CLAUSE_HOME/.local/logs`
- `MISE_DATA_DIR` $\rightarrow$ `$XDG_DATA_HOME/mise`
- `MISE_CONFIG_DIR` $\rightarrow$ `$XDG_CONFIG_HOME/mise`
- `MISE_STATE_DIR` $\rightarrow$ `$XDG_STATE_HOME/mise`
- `MISE_CACHE_DIR` $\rightarrow$ `$XDG_CACHE_HOME/mise`

### Consequences

#### Positive
- Zero footprint on host storage outside of the project workspace.
- Deleting `$CLAUSE_PROJECT_ROOT/.home` guarantees a complete, clean reset of all state.
- Automated tests (`test_hermeticity.nu`) programmatically verify that no process escapes the sandbox boundary.

#### Negative
- Tools assuming hardcoded system paths (e.g. `/etc` or `C:\ProgramData`) must be shimmed or configured via environment variables.
- Bootloader scripts must verify that directory structures exist prior to process execution.