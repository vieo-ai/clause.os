# tests/system/test_hermeticity.nu
use std assert

export def main [] {
    print "  [+] Testing Hermeticity & State Isolation..."

    let project_root = ($env.CLAUSE_PROJECT_ROOT? | default $env.PWD)
    let local_bin = ($project_root | path join ".local" "bin" | path expand)

    # 1. Assert PATH Precedence (.local/bin must be at index 0)
    let current_path_head = ($env.PATH | first | path expand)
    assert ($current_path_head == $local_bin) $"[Hermeticity Failure] PATH leak! Expected head ($local_bin), got ($current_path_head)"

    # 2. Assert Windows AppData isolation
    if ($nu.os-info.name == "windows") {
        let expected_appdata = ($project_root | path join ".local" "appdata" | path expand)
        let current_appdata = ($env.APPDATA | path expand)
        assert ($current_appdata == $expected_appdata) $"[Hermeticity Failure] APPDATA not confined! Got ($env.APPDATA)"
    }

    # 3. Assert Mise Nushell Overlay exists
    let mise_nu = ($project_root | path join ".config" "nushell" "mise.nu")
    assert ($mise_nu | path exists) "[Hermeticity Failure] Mise overlay file 'mise.nu' missing in .config/nushell/"

    # 4. Assert Bootstrap Log File exists and is non-empty
    let log_file = ($project_root | path join ".local" "logs" "bootstrap.log")
    assert ($log_file | path exists) "[Hermeticity Failure] Bootstrap log file missing at .local/logs/bootstrap.log"
    assert (($log_file | open | str length) > 0) "[Hermeticity Failure] Bootstrap log file is empty"

    print "  [✓] Hermeticity & State Isolation Verified Successfully."
}