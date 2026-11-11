# scripts/cli/nu/config/env.nu - ClauseOS Canonical Nushell Environment

# ==============================================================================
# 1. RESOLVE PROJECT ROOT & LOAD CANONICAL ENVIRONMENT FROM .ENV (SSOT)
# ==============================================================================
let project_root = if ("CLAUSE_PROJECT_ROOT" in $env) {
    $env.CLAUSE_PROJECT_ROOT
} else {
    $env.FILE_PWD | path join ".." ".." ".." ".." | path expand
}

# Ingest root .env file as canonical configuration data source
let dot_env_file = ($project_root | path join ".env")
if ($dot_env_file | path exists) {
    open $dot_env_file
    | lines
    | parse "{key}={value}"
    | where { |row| not ($row.key | str starts-with "#") and ($row.key | str trim | is-not-empty) }
    | each { |row|
        let clean_val = ($row.value | str trim | str trim --char '"' | str trim --char "'")
        load-env { ($row.key | str trim): $clean_val }
    }
}

let is_windows  = (($nu.os-info.name | str lowercase) == "windows")
let clause_home = ($project_root | path join ($env.CLAUSE_HOME? | default ".home"))

$env.CLAUSE_PROJECT_ROOT = $project_root
$env.CLAUSE_HOME         = $clause_home
$env.HOME                = $clause_home
$env.USERPROFILE         = $clause_home

# ==============================================================================
# 2. PLATFORM DIRECTORY ANCHORS
# ==============================================================================
if $is_windows {
    # --------------------------------------------------------------------------
    # Scrub all POSIX-specific keys from the Nushell environment on Windows.
    # Passing -i ignores missing keys without throwing errors.
    # --------------------------------------------------------------------------
    hide-env -i (
        [
            "XDG_CONFIG_HOME"
            "XDG_DATA_HOME"
            "XDG_STATE_HOME"
            "XDG_CACHE_HOME"
            "POSIX_CLAUSE_BIN_DIR"
            "POSIX_CLAUSE_APPS_DIR"
            "POSIX_CLAUSE_LOGS_DIR"
        ]
    )

    let win_local   = ($project_root | path join $env.WIN_LOCALAPPDATA)
    let win_roaming = ($project_root | path join $env.WIN_APPDATA)

    $env.LOCALAPPDATA = $win_local
    $env.APPDATA      = $win_roaming

    $env.CLAUSE_BIN_DIR   = ($project_root | path join $env.WIN_CLAUSE_BIN_DIR)
    $env.CLAUSE_APPS_DIR  = ($project_root | path join $env.WIN_CLAUSE_APPS_DIR)
    $env.CLAUSE_CACHE_DIR = ($project_root | path join $env.WIN_CLAUSE_CACHE_DIR)
    $env.CLAUSE_TEMP_DIR  = ($project_root | path join $env.WIN_CLAUSE_TEMP_DIR)
    $env.CLAUSE_LOGS_DIR  = ($project_root | path join $env.WIN_CLAUSE_LOGS_DIR)

    # --------------------------------------------------------------------------
    # HERMETIC NT HOME & SCRATCH LOCKDOWN (From .env definitions)
    # --------------------------------------------------------------------------
    $env.TEMP = ($project_root | path join $env.WIN_TEMP)
    $env.TMP  = ($project_root | path join $env.WIN_TMP)

    if ($env.WIN_HOMEDRIVE? | is-not-empty) and ($env.WIN_HOMEPATH? | is-not-empty) {
        $env.HOMEDRIVE = $env.WIN_HOMEDRIVE
        $env.HOMEPATH  = $env.WIN_HOMEPATH
    } else {
        let home_drive = ($clause_home | parse -r '^(?P<drive>[A-Za-z]:)(?P<path>\\.*)$')
        if ($home_drive | is-not-empty) {
            $env.HOMEDRIVE = $home_drive.0.drive
            $env.HOMEPATH  = $home_drive.0.path
        }
    }

    $env.MISE_DATA_DIR   = ($win_local | path join "mise")
    $env.MISE_CONFIG_DIR = ($win_roaming | path join "mise")
    $env.MISE_STATE_DIR  = ($win_local | path join "mise" "state")
    $env.MISE_CACHE_DIR  = ($win_local | path join "mise" "cache")
    $env.MISE_LOG_FILE   = ($win_local | path join "mise" "logs" "mise.log")
    $env.GH_CONFIG_DIR   = ($win_roaming | path join "GitHub CLI")
} else {
    # --------------------------------------------------------------------------
    # Scrub Windows-specific keys from the Nushell environment on POSIX.
    # --------------------------------------------------------------------------
    hide-env -i (
        [
            "WIN_LOCALAPPDATA"
            "WIN_APPDATA"
            "WIN_CLAUSE_BIN_DIR"
            "WIN_CLAUSE_APPS_DIR"
            "WIN_CLAUSE_LOGS_DIR"
            "WIN_CLAUSE_TEMP_DIR"
            "WIN_CLAUSE_CACHE_DIR"
        ]
    )
    
    $env.XDG_CONFIG_HOME = ($project_root | path join $env.XDG_CONFIG_HOME)
    $env.XDG_DATA_HOME   = ($project_root | path join $env.XDG_DATA_HOME)
    $env.XDG_STATE_HOME  = ($project_root | path join $env.XDG_STATE_HOME)
    $env.XDG_CACHE_HOME  = ($project_root | path join $env.XDG_CACHE_HOME)

    $env.CLAUSE_BIN_DIR   = ($project_root | path join $env.POSIX_CLAUSE_BIN_DIR)
    $env.CLAUSE_APPS_DIR  = ($project_root | path join $env.POSIX_CLAUSE_APPS_DIR)
    $env.CLAUSE_CACHE_DIR = $env.XDG_CACHE_HOME
    $env.CLAUSE_TEMP_DIR  = ($env.XDG_CACHE_HOME | path join "tmp_bootstrap")
    $env.CLAUSE_LOGS_DIR  = ($project_root | path join $env.POSIX_CLAUSE_LOGS_DIR)

    $env.MISE_DATA_DIR   = ($env.XDG_DATA_HOME | path join "mise")
    $env.MISE_CONFIG_DIR = ($env.XDG_CONFIG_HOME | path join "mise")
    $env.MISE_STATE_DIR  = ($env.XDG_STATE_HOME | path join "mise")
    $env.MISE_CACHE_DIR  = ($env.XDG_CACHE_HOME | path join "mise")
    $env.MISE_LOG_FILE   = ($env.XDG_STATE_HOME | path join "mise" "logs" "mise.log")
    $env.GH_CONFIG_DIR   = ($env.XDG_CONFIG_HOME | path join "gh")
}

# ==============================================================================
# 3. DIRECTORY INVARIANTS & HERMETIC SSH CONTAINMENT
# ==============================================================================
let ssh_dir = ($clause_home | path join ".ssh")

for dir in [$env.CLAUSE_CACHE_DIR $env.CLAUSE_BIN_DIR $ssh_dir] {
    if not ($dir | path exists) { mkdir $dir }
}

let ssh_config  = ($ssh_dir | path join "config")
let known_hosts = ($ssh_dir | path join "known_hosts")
let id_ed25519  = ($ssh_dir | path join "id_ed25519")
let id_rsa      = ($ssh_dir | path join "id_rsa")

# Format paths with forward slashes for cross-platform OpenSSH compatibility
let ssh_config_str  = ($ssh_config | str replace -a '\' '/')
let known_hosts_str = ($known_hosts | str replace -a '\' '/')
let id_ed_str       = ($id_ed25519 | str replace -a '\' '/')
let id_rsa_str      = ($id_rsa | str replace -a '\' '/')

if ($ssh_config | path exists) {
    $env.GIT_SSH_COMMAND = $"ssh -F '($ssh_config_str)' -o UserKnownHostsFile='($known_hosts_str)'"
} else {
    $env.GIT_SSH_COMMAND = $"ssh -i '($id_ed_str)' -i '($id_rsa_str)' -o UserKnownHostsFile='($known_hosts_str)'"
}

# Standalone SSH routing proxy for interactive commands in Nushell
def --env ssh [...args: string] {
    let cfg = ($env.CLAUSE_HOME | path join ".ssh" "config" | str replace -a '\' '/')
    if ($cfg | path exists) {
        ^ssh -F $cfg ...$args
    } else {
        ^ssh ...$args
    }
}

# ==============================================================================
# 4. IDENTITY & CONFIG ROUTING
# ==============================================================================
$env.GIT_CONFIG_GLOBAL = ($project_root | path join $env.GIT_CONFIG_GLOBAL)
$env.NU_CONFIG_DIR     = ($project_root | path join $env.NU_CONFIG_DIR)
$env.PULUMI_HOME       = ($project_root | path join $env.PULUMI_HOME)

# ==============================================================================
# 5. PATH INJECTION (STAGE 0 BINARIES ONLY)
# ==============================================================================
let bin_dir = ($env.CLAUSE_BIN_DIR | path expand)

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

if not ($current_paths | any { |p| 
    if ($p | path exists) { ($p | path expand) == $bin_dir } else { $p == $bin_dir }
}) {
    $env.PATH = ($current_paths | prepend $bin_dir)
} else {
    $env.PATH = $current_paths
}

# ==============================================================================
# 6. DYNAMIC MISE ACTIVATION OVERLAY GENERATION
# ==============================================================================
let mise_path = ($env.NU_CONFIG_DIR | path join "mise.nu")
if (which mise | is-not-empty) {
    ^mise activate nu | save $mise_path --force
}