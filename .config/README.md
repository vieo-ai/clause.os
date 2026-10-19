# `.config` — System Configuration VFS

> **Subsystem Role:** XDG Configuration Home (`$XDG_CONFIG_HOME`)

The `.config` directory serves as the isolated home for all application and toolchain configuration files within the confined `/clause` userland.

---

## Directory Function

* **Environment Confinement:** Forces userland applications (`git`, `gh`, `nushell`, `pwsh`) to store their runtime configurations strictly inside `/clause/.config` instead of the host user's home directory.
* **Hermetic Settings:** Ensures system behavior, aliases, keybindings, and prompts remain completely reproducible regardless of the underlying host OS.

---

## Expected Subdirectories

```text
.config/
├── git/        # Global Git configuration (config, ignore)
├── gh/         # GitHub CLI configuration & authentication state
├── nushell/    # Nushell OS init scripts (env.nu, config.nu)
└── pwsh/       # PowerShell subshell configuration
```