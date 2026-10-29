# ADR 013: Curated Domain SLMs vs. Saturated Generalist Models (The Contained Cup Architecture)

## Status
Accepted

## Context
Frontier foundation models (70B–400B+ parameters) are trained on massive, unstructured open-web datasets. While effective for conversational synthesis and human interaction, this causes severe "information saturation" in operational and systems programming tasks. Over-saturated models retain latent representations of evasion, sycophancy, conflicting framework dialects, and outdated conventions. When running critical execution paths, this broad entropy causes hallucinated flags, context drift, and unverified narrative claims.

## Decision
Adopt a **Two-View Architectural Model** separating human-facing conversational steering from deterministic, task-specific worker execution:

1. **View 1: Conversational Intent & Steering (The Reservoir)**:
   * Frontier/generalist models are restricted exclusively to the human-collaboration boundary (e.g., interactive steering with the `ceo_agent` or `cto_agent` in the portable VS Code host).
   * Their sole responsibility is intent elicitation, task breakdown, and schema-constrained task specification. They are prohibited from direct, unverified execution on system state.

2. **View 2: Contained Operational Worker SLMs (The Cup)**:
   * Worker agents (e.g., backend developers, QA auditors, systems operators) utilize distilled Small Language Models (1B–7B parameters) fine-tuned locally via Unsloth.
   * **Domain-Restricted Weight Space**: Training sets are saturated exclusively with canonical ground truth: verified project ADRs, compiler ASTs, type contracts, and deterministic test vectors.
   * **Elimination of Evasion Vectors**: By omitting conversational noise, corporate jargon, and rhetorical transcripts from training sets, worker models lack the latent weight representations necessary to fabricate excuses, hallucinate non-existent tools, or provide misleading completion claims.
   * **Single-Minded Execution**: Like specialized, single-purpose automation routines, worker SLMs execute their assigned schema contract, verify their output against local assertion gates, return binary exit codes, and terminate.

## Consequences
* **Positive**: Drastically lowers latency and VRAM consumption; permits multi-agent organizations to execute concurrently on local consumer hardware.
* **Positive**: Drastically minimizes hallucination by sharpening token probability peaks around the project's exact syntax and conventions.
* **Positive**: Eliminates sycophantic narrative loops; worker models cannot fabricate plausible-sounding excuses for broken builds.
* **Negative**: Requires maintaining local fine-tuning and distillation datasets as project architectures evolve.