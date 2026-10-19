# `.local` — Userland Binary & Application Data VFS

> **Subsystem Role:** XDG Data & Binary Home (`$XDG_DATA_HOME` / `$XDG_BIN_HOME`)

The `.local` directory contains all executable binaries, installed shims, persistent application state, and portable IDE/daemon assets.

---

## Directory Function

* **`.local/bin`:** The unified binary directory where `mise` places executable shims, pre-seeded bootstrapper binaries (`mise`, `nu`, `just`), and userland tools. This is the **only** custom directory prepended to `$PATH`.
* **`.local/app`:** Holds portable standalone applications such as VS Code (operating in portable mode via a local `data/` folder) and neural daemons (`lemonade`, `fastflowlm`).
* **`.local/share`:** Holds persistent databases, application runtime data, local Vault/Nomad state, and internal logs.

---

## Structure

```text
.local/
├── app/        # Portable application bundles (vscode, lemonade, fastflowlm)
├── bin/        # Unified binary directory and Mise shims ($PATH target)
└── share/      # Persistent application data, state, and databases
```