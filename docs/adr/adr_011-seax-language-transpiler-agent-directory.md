# ADR 011: Seax Programming Language, Multi-Target Transpiler, and Directory-Based Agent Architecture

## Status
Accepted

## Context
Authoring complex transmedia pipelines (audio, video, SMPTE, MIDI, NDI, Dante), autonomous multi-agent hierarchies, and distributed infrastructure in disconnected DSLs, prompt templates, and shell scripts causes brittle glue code and high cognitive overhead.

## Decision
Create **Seax** (extension `.cx`), a carrier-class programming language engineered in Rust using Thorsten Ball’s compiler principles, Mark Sibley’s Monkey X multi-target transpilation model, and Jet's agent abstractions:

1. **Language Design & Syntax**:
   * **Dart/OOP Ergonomics**: Familiar class-based, interface-driven object-oriented syntax enriched with Laravel service-provider lifecycles and Fowler enterprise patterns.
   * **First-Class Domain Primitives**: Dedicated language keywords for transmedia (`audio`, `video`, `midi`, `ndi`, `osc`, `smpte`, `dante`) and agentic infrastructure (`agent`, `actor`, `telcom`, `process`, `container`, `broadcast`).
   * **Concept-as-Code**: Agent behaviors, MCP server bridges, and infrastructure deployments execute as native code rather than loose Markdown prompts.

2. **Monkey X Multi-Target Transpiler Architecture (Written in Rust)**:
   * Rather than confining code to an emulated virtual machine, the Seax compiler (`seaxc`) transcompiles `.cx` source down to target-native code:
     * **Target `beam`**: Transpiles to Core Erlang / BEAM bytecode for cluster execution, OTP actor trees, and scheduler dispatch.
     * **Target `native-dsp`**: Transpiles real-time audio/video processing blocks into high-performance C++20 / Rust NIFs linked to JUCE or hardware SDKs.
     * **Target `client`**: Transpiles UI viewports, agent monitors, and MCP schemas into TypeScript / WebAssembly.
   * Supports target-conditional compilation (`#if TARGET == "beam"`).

3. **Unified "Agent is a Directory" Architecture**:
   * Blends Jet’s "agent as file" model with Monkey X package modularity.
   * An agent or complete department is an isolated directory containing:
     * Root coordinator (`agent.cx`) and sub-agent files (`team/*.cx`).
     * Executable skill definitions (`skills/*.cx`).
     * Embedded MCP servers (`mcp/*/server.cx`).
     * Native DSP/NIF plugins (`plugins/*.cx`).
     * Manifest, permissions, and leased credentials (`package.seax`).
   * An agent directory can compile and execute as a headless BEAM service, an HTTP API, a desktop tool, or a Nomad worker job.

## Consequences
* **Positive**: Unmatched execution range—one language syntax drives real-time audio/video DSP, cloud orchestration, and autonomous agent logic.
* **Positive**: Packaging agents as self-contained directories eliminates configuration sprawl and makes agent departments portable and versionable.
* **Positive**: Static type safety and compile-time validation for distributed agent messaging and hardware buses.
* **Negative**: Requires building and maintaining a custom Rust compiler frontend (lexer, Pratt parser, semantic analyzer) and multi-backend code generators.