# `ops` — Infrastructure Declarations & Orchestration Stack

> **Subsystem Role:** Declarative Cloud & Cluster Orchestration Layer

The `ops` directory houses Pulumi infrastructure-as-code stacks, Nomad job specs, Consul service catalogs, and Vault secret policies.

---

## Directory Function

* **Cloud Bursting Engine:** Contains Pulumi code (TypeScript/Python) to provision external compute resources across cloud providers.
* **Local & Remote Cluster Specs:** Manages Nomad job definitions and Consul network topology specs for both local seed node and remote cloud deployments.

---

## Structure

```text
ops/
├── consul/     # Service mesh configurations and Raft join rules
├── nomad/      # Job specs for application workloads & daemons
├── pulumi/     # Infrastructure stack definitions (AWS, Hetzner, Bare Metal)
└── vault/      # Cryptographic policies and unseal parameters
```