# `ci` — Continuous Integration & Verification Pipelines

> **Subsystem Role:** Automation Scripts & Pipeline Definitions

The `ci` directory contains continuous integration workflows, validation scripts, and automated build targets designed to run both locally and in CI/CD runners.

---

## Directory Function

* **Reproducible Pipeline Executable:** Ensures CI runners test the exact same scripts used in local development (`clause.sh`, `just test`).
* **Environment Confinement Verification:** Automated checks that fail CI if any file modification occurs outside the `/clause` root.
* **Artifact Packaging:** Generates release archives and pre-seeded bootstrap templates.