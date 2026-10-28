# tests/system/test_hermeticity.nu
use std assert

export def main [] {
    print "  [+] Testing Hermeticity & State Isolation..."

    let project_root = ($env.CLAUSE_PROJECT_ROOT? | default $env.PWD)
    let clause_home = ($env.CLAUSE_HOME? | default ($project_root | path join ".home") | path expand)
    let is_windows = (($nu.os-info.name | str lowercase) == "windows")

    # 1. Assert HOME and USERPROFILE confinement
    let current_home = ($env.HOME? | default "" | path expand)
    let current_userprofile = ($env.USERPROFILE? | default "" | path expand)
    assert ($current_home == $clause_home) $"[Hermeticity Failure] HOME not confined! Expected ($clause_home), got ($current_home)"
    assert ($current_userprofile == $clause_home) $"[Hermeticity Failure] USERPROFILE not confined! Expected ($clause_home), got ($current_userprofile)"

    # 2. Assert hermetic binary directory exists in PATH
    let default_bin = if $is_windows {
        $clause_home | path join "AppData" "Local" "Programs" "bin"
    } else {
        $clause_home | path join ".local" "bin"
    }

    # Ensure the directory actually exists so symlinks resolve identically
    let target_bin = ($env.CLAUSE_BIN_DIR? | default $default_bin)
    if not ($target_bin | path exists) {
        mkdir $target_bin
    }
    let local_bin = ($target_bin | path expand)

    # Normalize $env.PATH: defensively handle lists, strings, and cross-shell delimiter bleeding (; vs :)
    let raw_entries = if ($env.PATH | describe | str starts-with "list") {
        $env.PATH
    } else {
        $env.PATH | split row (char esep)
    }

    let expanded_path = ($raw_entries 
        | flat-map { |entry| $entry | split row ";" }
        | flat-map { |entry| $entry | split row ":" }
        | where { |entry| ($entry | str trim) != "" }
        | each { |p| if ($p | path exists) { $p | path expand } else { $p } }
    )
    
    let path_contains_bin = ($expanded_path | any { |p| $p == $local_bin })
    
    assert $path_contains_bin $"[Hermeticity Failure] Hermetic binary directory ($local_bin) not found in PATH:\n($expanded_path | to yaml)"

    # 3. Assert platform application data isolation
    if $is_windows {
        let expected_appdata = ($clause_home | path join "AppData" "Roaming" | path expand)
        let expected_localappdata = ($clause_home | path join "AppData" "Local" | path expand)
        let current_appdata = ($env.APPDATA? | default "" | path expand)
        let current_localappdata = ($env.LOCALAPPDATA? | default "" | path expand)

        assert ($current_appdata == $expected_appdata) $"[Hermeticity Failure] APPDATA not confined! Expected ($expected_appdata), got ($current_appdata)"
        assert ($current_localappdata == $expected_localappdata) $"[Hermeticity Failure] LOCALAPPDATA not confined! Expected ($expected_localappdata), got ($current_localappdata)"
    } else {
        let expected_config = ($clause_home | path join ".config" | path expand)
        let expected_data = ($clause_home | path join ".local" "share" | path expand)
        let current_config = ($env.XDG_CONFIG_HOME? | default "" | path expand)
        let current_data = ($env.XDG_DATA_HOME? | default "" | path expand)

        assert ($current_config == $expected_config) $"[Hermeticity Failure] XDG_CONFIG_HOME not confined! Expected ($expected_config), got ($current_config)"
        assert ($current_data == $expected_data) $"[Hermeticity Failure] XDG_DATA_HOME not confined! Expected ($expected_data), got ($current_data)"
    }

    # 4. Assert Mise Nushell Overlay exists
    let nu_config_dir = ($env.NU_CONFIG_DIR? | default ($project_root | path join "scripts" "cli" "nu" "config"))
    let mise_nu = ($nu_config_dir | path join "mise.nu")
    assert ($mise_nu | path exists) $"[Hermeticity Failure] Mise overlay file 'mise.nu' missing in ($nu_config_dir)"

    # 5. Assert Bootstrap Log File exists and is non-empty
    let default_logs = if $is_windows {
        $clause_home | path join "AppData" "Local" "Programs" "logs"
    } else {
        $clause_home | path join ".local" "logs"
    }
    let log_dir = ($env.CLAUSE_LOGS_DIR? | default $default_logs)
    let log_file = ($log_dir | path join "bootstrap.log")
    assert ($log_file | path exists) $"[Hermeticity Failure] Bootstrap log file missing at ($log_file)"
    assert (($log_file | open | str length) > 0) $"[Hermeticity Failure] Bootstrap log file at ($log_file) is empty"

    print "  [✓] Hermeticity & State Isolation Verified Successfully."
}