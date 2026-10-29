# ADR 010: Distributed BEAM Backplane, Gleam Orchestration, Nomad Scheduling, and Bare-Metal Provisioning

## Status
Accepted

## Context
ClauseOS requires an infrastructure and compute substrate capable of delivering Bare Metal as a Service (MaaS), dynamic cluster orchestration, and resilient workload supervision without the massive control-plane footprint, etcd fragility, and operational overhead of bare-metal Kubernetes.

## Decision
Establish the infrastructure hierarchy around a decentralized, fault-tolerant backplane where Kubernetes is demoted from a platform orchestrator to an ephemeral tenant workload:

1. **BEAM Backplane & Gleam Orchestrator**:
   * **Primary Language**: Gleam is the primary language for building cluster daemons, node supervisors, and API adapters.
   * **Supervision & Fault Isolation**: Utilizes typed OTP supervision trees (`gleam_otp`) to maintain soft real-time node tracking, agent mailbox lifecycles, and self-healing cluster meshes.
   * **Zero etcd Tax**: Node clustering and telemetry are coordinated through distributed BEAM actor links rather than monolithic consensus databases.

2. **Workload Execution Plane (HashiCorp Nomad)**:
   * Acts as the raw execution engine driven by the Gleam orchestrator.
   * Schedules bare-metal binaries (`raw_exec`), local GPU workloads, and container runtimes.
   * Ephemeral Kubernetes clusters (e.g., k3s) are treated as on-demand guest workloads within isolated micro-instances (`cx vm`) or containers.

3. **Bare Metal as a Service (MaaS & Netboot)**:
   * **iPXE Engine**: Embed **Pixiecore** to deliver zero-touch, API-driven network booting directly coordinated via the BEAM orchestrator and Consul catalog.
   * **Golden Immutable Images**: Use **Packer** to generate minimal, in-memory boot artifacts (e.g., Talos, Flatcar, or custom Alpine rootfs) pre-seeded with the ClauseOS Stage 0 trampoline.

4. **Programmatic Infrastructure as Code (Pulumi)**:
   * Replace static HCL Terraform workflows with the **Pulumi Automation API**, driving physical networking, cloud-burst nodes, and service DNS programmatically via code.

## Consequences
* **Positive**: Complete bare-metal control from initial power-on (IPMI/PXE) to distributed AI agent execution.
* **Positive**: Extremely low control-plane footprint compared to platforms like CozyStack or Typhoon.
* **Positive**: Kubernetes is isolated to guest application needs rather than governing system infrastructure.
* **Negative**: Requires authoring and maintaining Gleam/OTP HTTP adapters for Nomad, Consul, and Vault.