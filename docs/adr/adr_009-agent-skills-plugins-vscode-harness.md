# ADR 009: VS Code Agent Host, Extensibility Plugins, and Skill Toolsets

## Status
Accepted

## Context
Developers need an interactive graphical control plane to steer, monitor, and collaborate with the Virtual Enterprise agents. The harness must support modular extensibility (skills and plugins) without introducing unconfined host extensions, global node modules, or external network dependencies.

## Decision
1. **Host Interface**: Embed and isolate **Portable VS Code** (`.home/.local/app/vscode/` or platform equivalent) as the primary graphical command center:
   - User profile, workspace state, and extensions reside strictly within `$env:CLAUSE_HOME`.
   - The editor is pre-configured to communicate directly with local coprocessor endpoints (`http://127.0.0.1:8000/v1`) and the Nomad/Consul cluster.

2. **Skill Toolset Architecture (`.enterprise/skills/`)**:
   - Skills are modular, declarative tool definitions executed via the local CLI (`cx`).
   - Every skill provides a schema contract:
     ```toml
     # .enterprise/skills/git-ops/skill.toml
     name = "git-ops"
     description = "Branching, staging, committing, and diffing workspace changes"
     runtime = "nu"
     entrypoint = "run.nu"
     permissions = ["repo:read", "repo:write"]
     ```
   - Standard built-in skills: `git-ops`, `code-analysis`, `test-runner`, `adr-writer`, `model-eval`.

3. **Plugin Extensibility (`.enterprise/plugins/`)**:
   - Plugins extend agent reasoning by providing domain-specific hooks and event listeners.
   - Stage 0 / Stage 1 initialization scripts discover and register active plugins into the agent harness without requiring editor restarts.

## Consequences
- **Positive**: Complete UI isolation—no host VS Code configurations or global extensions are modified.
- **Positive**: Reusable, language-agnostic skill authoring (Nushell, PowerShell, or Python scripts) packaged with clear permission scopes.
- **Negative**: Requires maintaining isolated VS Code runtime settings and keybindings within the `.home/` profile.