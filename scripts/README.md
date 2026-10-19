# `scripts` — System Command Routers & Nushell Modules

> **Subsystem Role:** OS Command Processing & Automation Subsystem

The `scripts` directory contains the executable command routers and Nushell modules that power the `clause` CLI interface.

---

## Directory Function

* **Command Routing:** Defines structured Nushell commands (e.g., `clause pkg install`, `clause cloud up`) as clean, typed function modules.
* **Lifecycle Hooks:** Automates Stage 1 hydration, environment synchronization, and cluster orchestration routines.

---

## Structure

```text
scripts/
└── console/
    └── nu/
        ├── commands/
        │   ├── pkg.nu      # Package hydration & driver router
        │   └── cloud.nu    # Cloud bursting & detachment router
        └── mod.nu          # Root module entry point
```