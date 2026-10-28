# ADR 004: Cross-Shell Environment and PATH Delimiter Canonicalization

- **Status**: Accepted
- **Date**: 2026-10-28
- **Context**: Inter-Shell State Passing (PowerShell, Nushell, POSIX sh)

## Context and Problem Statement

ClauseOS operates across multiple shell engines:
- PowerShell (`pwsh`) drives the microkernel bootloader.
- Nushell (`nu`) serves as the primary interactive workbench shell.
- POSIX shell (`sh`) handles fallback environments.

During CI/CD and cross-shell transitions, differing shell assumptions caused critical failures:
1. **Delimiter Bleeding**: PowerShell on Windows uses `;` to separate PATH entries, whereas POSIX shells and Nushell on Linux/macOS use `:`. Injecting shims with hardcoded delimiters caused combined strings (e.g., `/mise/shims;/local/bin`) to end up as single malformed list elements.
2. **Nushell Parse-Time Evaluation**: Nushell evaluates `source` at parse time, throwing `nu::shell::not_a_constant` when attempting to dynamically resolve runtime variables inside `config.nu`.
3. **Symlink Ambiguity**: On macOS, `/var` vs `/private/var` symlinks caused string comparisons against `$env.PATH` to fail assertion tests.
4. **Command Deprecation**: Invoking deprecated commands (e.g. `flat-map`) caused runtime errors across non-standard Nushell builds.

## Decision Outcome

Implement cross-shell canonicalization rules across all environment entrypoints.

### Core Implementation Rules

1. **Platform-Aware Path Injection in Bootloader**:
   PowerShell must inject PATH entries using the platform-specific separator:
   ```powershell
   $PathSep = if ($IsOSWindows) { ";" } else { ":" }
   $env:PATH = "$TargetShim$PathSep$env:PATH"
   ```

2. **Defensive Two-Pass PATH Splitting in Nushell (`env.nu` & `test_hermeticity.nu`)**:
   Nushell normalizes PATH by handling lists and splitting across both `;` and `:`:
   ```nu
   let raw_paths = if ($env.PATH | describe | str starts-with "list") {
       $env.PATH
   } else {
       $env.PATH | split row (char esep)
   }

   let current_paths = ($raw_paths
       | each { |p| $p | split row ";" }
       | flatten
       | each { |p| $p | split row ":" }
       | flatten
       | where { |p| ($p | str trim) != "" }
   )
   ```

3. **Pre-Materialization of Anchor Paths**:
   Before performing `path expand` on directory anchors, scripts must guarantee that target directories exist on disk (`mkdir`), ensuring deterministic symlink resolution.

4. **Static Relative Parse Sourcing for Nushell**:
   `env.nu` pre-generates `scripts/cli/nu/config/mise.nu`, allowing `config.nu` to load it statically via `source ./mise.nu` without runtime variables.

### Consequences

#### Positive
- Flawless CI/CD verification across Windows, Ubuntu, and macOS runners.
- Zero PATH fragmentation or mangled environment variables during shell handoffs.

#### Negative
- Slightly more verbose PATH handling in Nushell configurations.