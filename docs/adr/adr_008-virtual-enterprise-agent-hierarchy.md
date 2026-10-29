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

### 4. Adversarial Verification & Gatekeeper Guardrails
* **Untrusted Worker Output**: Verbal completion claims ("I fixed the issue and tests pass") from worker agents are classified as unverified hypotheses.
* **Independent Supervisory Validation**: Task state cannot advance to `COMPLETED` until an independent supervisory agent executes deterministic verification gates against the generated artifact.
* **Mechanical Assertion Contracts**:
  - Exit code `0` from the hermetic test runner (`run_tests.nu`).
  - Zero out-of-boundary path modifications via git diff assertions.
  - Schema conformity verification.
* **Gated Leases**: Vault dynamically issues short-lived merge tokens exclusively to the supervisor upon mechanical assertion pass.

### 5. Source-Grounded Single Source of Truth (SSOT) & Closed-World Invariant
* **Closed-World Constraint**: The repository documentation (`docs/adr/`, `TASK.md`, and versioned schemas) represents the sole canonical ground truth. Speculative training knowledge not anchored in local source material is classified as unverified hallucination.
* **Bidirectional Traceability**: Code artifacts, configuration keys, and architectural structures must trace directly to an accepted ADR or schema specification.
* **Dual-Plane Separation**:
  - *Human Collaboration Plane (Chat)*: Conversational, flexible, and iterative; compiles human intent into grounded task specifications.
  - *Operational Execution Plane (Strict)*: Non-conversational, deterministic, and role-locked; executed via Nomad `raw_exec` with binary exit codes.

## Consequences
- **Positive**: Provides deterministic, role-specific agents that stay focused on designated tasks without drifting out of scope.
- **Positive**: High enterprise auditability—every agent action maps to a job ticket, execution log, and git commit.
- **Negative**: Requires formal schema definitions and config files per role before an agent can begin execution.