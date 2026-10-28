# ADR 008: Virtual Enterprise Organizational Hierarchy & Agent Governance

## Status
Accepted

## Context
ClauseOS requires an autonomous multi-agent operating structure to execute end-to-end development, architecture governance, security auditing, and delivery workflows directly within the workspace. Rather than relying on flat conversational loops or unconstrained prompt chains, the system requires a structured organizational hierarchy with explicit lines of authority, role segregation, and guardrails for repository write access.

## Decision
Establish a structured **Virtual Enterprise** framework anchored within the `.enterprise/` repository root:

1. **Governance & Organizational Tiers**:
   - **The Board / Constitution (`.enterprise/board/`)**: Top-level constraints, immutable boundaries (e.g., license preservation, sandbox isolation, spend limits), and strategic objectives defined in `constitution.toml`.
   - **Executive Tier (`.enterprise/executive/`)**: Cross-department orchestration.
     - `ceo_agent`: Roadmaps, milestone planning, and high-level issue assignment.
     - `cto_agent`: Architectural integrity, ADR enforcement, code quality standards.
     - `cpo_agent`: UX consistency, CLI ergonomics, feature delivery tracking.
   - **Operational Departments (`.enterprise/departments/`)**:
     - `engineering`: Feature implementation, bug fixes, refactoring, test suites.
     - `security_audit`: Dependency vulnerability checks, hermetic boundary verification, secret leak prevention.
     - `site_reliability`: Nomad workload health, Consul service mesh integrity, telemetry.
     - `documentation_qa`: ADR authoring, README synchronization, task tracking.

2. **Communication & Coordination Primitives**:
   - **Service & Mailbox Discovery**: Agents register capabilities and status via **Consul**.
   - **Workload Execution**: Autonomous batch operations (code generation, test passes, model runs) are scheduled through **Nomad** using `raw_exec` tasks confined to `.home/`.
   - **Access Leases**: Repository write credentials and sensitive keys are dynamically granted via short-lived **Vault** leases.

3. **Workspace Confinement & Auditability**:
   - Agents operate strictly under `$env:CLAUSE_PROJECT_ROOT` with changes isolated to dedicated feature branches.
   - Direct writes to protected branches (`main`, `release/*`) are strictly forbidden; all pull/merge actions require a green pass from the local assertion test suite.

## Consequences
- **Positive**: Provides deterministic, role-specific agents that stay focused on designated tasks without drifting out of scope.
- **Positive**: High enterprise auditability—every agent action maps to a job ticket, execution log, and git commit.
- **Negative**: Requires formal schema definitions and config files per role before an agent can begin execution.