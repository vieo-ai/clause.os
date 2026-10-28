# ADR 007: Open-Core Substrate vs. Industry Adaptation Commercialization

## Status
Accepted

## Context
Defining the boundary between the open-source base repository and future commercial/monetized editions is necessary to guide development priorities and avoid artificial feature crippleware.

## Decision
1. **Unconstrained Open-Core Substrate**:
   - The open-source repository is a fully functional, self-contained operating system workbench.
   - Node count, clustering (Nomad/Consul/Vault), cloud bursting (Pulumi), GPU acceleration, and agent harnesses are **never paywalled or artificially limited**.
2. **Monetization via Industry Adaptation**:
   - Commercial offerings take the form of specialized, turnkey **Virtual Enterprise Cartridges** built on top of the open substrate.
   - Revenue streams focus on:
     - Regulated industry adaptations (HIPAA Healthcare, FINRA/SEC FinTech, Defense/Aerospace air-gapped packages).
     - Cryptographic agent audit trails, governance, and Open Policy Agent (OPA) compliance engines.
     - Enterprise system bridges (SAP, Oracle, Epic, corporate Active Directory).

## Consequences
- **Positive**: Drives adoption among developers who gain a powerful, unconstrained tool.
- **Positive**: Enterprise buyers pay for domain-specific risk reduction, compliance, and pre-packaged agent teams rather than low-level software licenses.