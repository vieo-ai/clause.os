# scripts/cli/nu/config/env.nu - ClauseOS Canonical Nushell Environment

# 1. Inherit or Resolve Project Root
let project_root = if ("CLAUSE_PROJECT_ROOT" in $env) {
    $env.CLAUSE_PROJECT_ROOT
} else {
    $env.FILE_PWD | path join ".." ".." ".." ".." | path expand
}

let clause_home = ($project_root | path join ".home")
let is_windows  = (($nu.os-info.name | str lowercase) == "windows")

$env.CLAUSE_PROJECT_ROOT = $project_root
$env.CLAUSE_HOME         = $clause_home
$env.HOME                = $clause_home
$env.USERPROFILE         = $clause_home

# 2. Platform Directory Anchors
if $is_windows {
    let win_local   = ($clause_home | path join "AppData" "Local")
    let win_roaming = ($clause_home | path join "AppData" "Roaming")

    $env.LOCALAPPDATA = $win_local
    $env.APPDATA      = $win_roaming

    $env.CLAUSE_BIN_DIR   = ($win_local | path join "Programs" "bin")
    $env.CLAUSE_APPS_DIR  = ($win_local | path join "Programs" "apps")
    $env.CLAUSE_CACHE_DIR = ($win_local | path join "cache")
    $env.CLAUSE_TEMP_DIR  = ($win_local | path join "Temp")
    $env.CLAUSE_LOGS_DIR  = ($win_local | path join "Programs" "logs")

    $env.MISE_DATA_DIR   = ($win_local | path join "mise")
    $env.MISE_CONFIG_DIR = ($win_roaming | path join "mise")
    $env.MISE_STATE_DIR  = ($win_local | path join "mise" "state")
    $env.MISE_CACHE_DIR  = ($win_local | path join "mise" "cache")
    $env.GH_CONFIG_DIR   = ($win_roaming | path join "GitHub CLI")
} else {
    $env.XDG_CONFIG_HOME = ($clause_home | path join ".config")
    $env.XDG_DATA_HOME   = ($clause_home | path join ".local" "share")
    $env.XDG_STATE_HOME  = ($clause_home | path join ".local" "state")
    $env.XDG_CACHE_HOME  = ($clause_home | path join ".cache")

    $env.CLAUSE_BIN_DIR   = ($clause_home | path join ".local" "bin")
    $env.CLAUSE_APPS_DIR  = ($clause_home | path join ".local" "apps")
    $env.CLAUSE_CACHE_DIR = $env.XDG_CACHE_HOME
    $env.CLAUSE_TEMP_DIR  = ($clause_home | path join ".cache" "tmp_bootstrap")
    $env.CLAUSE_LOGS_DIR  = ($clause_home | path join ".local" "logs")

    $env.MISE_DATA_DIR   = ($env.XDG_DATA_HOME | path join "mise")
    $env.MISE_CONFIG_DIR = ($env.XDG_CONFIG_HOME | path join "mise")
    $env.MISE_STATE_DIR  = ($env.XDG_STATE_HOME | path join "mise")
    $env.MISE_CACHE_DIR  = ($env.XDG_CACHE_HOME | path join "mise")
    $env.GH_CONFIG_DIR   = ($env.XDG_CONFIG_HOME | path join "gh")
}

# 3. Directory Invariants & Hermetic SSH Containment
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

# 4. Identity & Config Routing
$env.GIT_CONFIG_GLOBAL = ($clause_home | path join ".gitconfig")
$env.NU_CONFIG_DIR     = ($project_root | path join "scripts" "cli" "nu" "config")
$env.PULUMI_HOME       = ($clause_home | path join ".pulumi")

# 5. PATH Injection (Stage 0 Binaries Only)
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

# 6. Dynamic Mise Activation Overlay Generation
let mise_path = ($env.NU_CONFIG_DIR | path join "mise.nu")
^mise activate nu | save $mise_path --force