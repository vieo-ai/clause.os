# `packages` — Internal Subsystem Modules & Libraries

> **Subsystem Role:** Monorepo Internal Package Space

The `packages` directory contains domain-specific libraries, custom Gleam/Python actors, and shared system code utilized across ClauseOS services.

---

## Directory Function

* **Gleam Background Actors:** Houses type-safe Gleam services running on the BEAM VM for cluster monitoring and automated quorum promotion.
* **Utility Modules:** Shared helper scripts, custom CLI extensions, and API client bindings.