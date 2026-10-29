# ADR 012: RinG (Rust-in-Gleam) Type-Safe Native Integration Bridge

## Status
Accepted

## Context
ClauseOS requires high-performance, low-latency execution for DSP, hardware protocol buses (MIDI, NDI, Dante), and file operations. Hand-rolling manual Erlang NIF bindings or C-FFI layers is error-prone, risks crashing the BEAM VM, and lacks static type synchronization between Rust and Gleam.

## Decision
Establish **RinG** (Rust in Gleam), an automated interface bridge inspired by Rinf (Rust in Flutter):

1. **Schema-Driven Contract Generation**:
   * Shared schemas generate typed Gleam types and corresponding Rust structs.
   * Eliminates hand-written binary parsing and Erlang term format marshalling.

2. **Scheduler Safety & Non-Blocking Isolation**:
   * Fast, non-blocking calls map directly to clean Rustler NIFs.
   * Heavy compute tasks automatically execute on BEAM `DirtyCpu` / `DirtyIo` schedulers or via asynchronous message-passing ports.
   * Memory safety in Rust guarantees zero segfaults or uncontrolled memory leaks.

3. **First-Class OTP Integration**:
   * RinG packages Rust services as native Gleam OTP actors (`gleam_otp`).
   * Native components participate directly in standard supervision trees and lifecycle events.

## Consequences
* **Positive**: Delivers near C-speed performance for media and system primitives while maintaining Gleam's static type guarantees.
* **Positive**: Eradicates the manual glue-code tax when bridging Rust algorithms into the ClauseOS orchestrator.
* **Negative**: Requires maintaining a code-generator tool (`ring-codegen`) inside the compiler/toolchain layer.