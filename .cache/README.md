# `.cache` — Transient Cache & Toolchain Hydration VFS

> **Subsystem Role:** XDG Cache Home (`$XDG_CACHE_HOME`)

The `.cache` directory acts as the transient storage layer for downloaded archives, language runtime caches, and `mise` toolchain installations.

---

## Directory Function

* **Isolated Hydration:** Keeps downloaded binary tarballs, compiler caches, and package archives contained inside `/clause/.cache` so host temp directories remain untouched.
* **Toolchain Storage:** Stores managed runtime distributions downloaded by `mise` (Python, Bun, Zig, Erlang/Gleam).

---

## Structure

```text
.cache/
├── m-cache/      # Download short-path cache for raw archives
└── toolchain/    # Mise managed runtimes, plugins, and backend cache
```