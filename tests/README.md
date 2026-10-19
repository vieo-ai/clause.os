# `tests` — System Integration & Verification Suite

> **Subsystem Role:** End-to-End Environment & Bootloader Validation

The `tests` directory houses test suites, boot checks, and isolation verification scripts that validate the ClauseOS environment across supported platforms.

---

## Directory Function

* **Bootloader Testing:** Validates that Stage 0 launchers (`clause.ps1`, `clause.sh`) correctly isolate `$HOME` and `$USERPROFILE`.
* **Hermeticity Verification:** Asserts that no tool installs, temp files, or configurations escape into host system paths during execution.
* **CLI & Command Routing Tests:** Ensures Nushell command routers (`scripts/console/nu/commands/*.nu`) and Just tasks execute cleanly.

---

## Structure

```text
tests/
├── bootloader/     # Tests for clause.ps1 and clause.sh environment confinement
├── integration/    # System package hydration and Mise driver tests
└── cloud/          # Mock cloud bursting and detachment verification
```