# tests/system/test_stage0.nu
use std assert

export def main [] {
    print "  [+] Testing Stage 0: Core Binaries..."

    let project_root = ($env.CLAUSE_PROJECT_ROOT? | default $env.PWD)
    let is_windows = (($nu.os-info.name | str lowercase) == "windows")
    let exe_ext = if $is_windows { ".exe" } else { "" }

    # Resolve bin directory from canonical env or derive from .home
    let default_bin = if $is_windows {
        $project_root | path join ".home" "AppData" "Local" "Programs" "bin"
    } else {
        $project_root | path join ".home" ".local" "bin"
    }
    let local_bin = ($env.CLAUSE_BIN_DIR? | default $default_bin)

    # List of expected Stage 0 executables
    let required_binaries = ["mise", "nu"]

    for $bin in $required_binaries {
        let bin_path = ($local_bin | path join $"($bin)($exe_ext)")
        
        # Assertion 1: Executable exists in hermetic bin directory
        assert ($bin_path | path exists) $"[Stage 0 Failure] Executable missing at ($bin_path)"

        # Assertion 2: Executable runs cleanly and returns exit code 0
        let run_check = (^$bin_path --version | complete)
        assert ($run_check.exit_code == 0) $"[Stage 0 Failure] ($bin) failed execution: ($run_check.stderr)"
    }

    print "  [✓] Stage 0 Core Binaries Verified Successfully."
}