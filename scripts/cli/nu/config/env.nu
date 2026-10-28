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
}

# Ensure the root cache directory exists on disk
if not ($env.CLAUSE_CACHE_DIR | path exists) {
    mkdir $env.CLAUSE_CACHE_DIR
}

# 3. Dedicated Config and Identity Routing
$env.GIT_CONFIG_GLOBAL = ($clause_home | path join ".gitconfig")
$env.NU_CONFIG_DIR     = ($project_root | path join "scripts" "cli" "nu" "config")

# 4. PATH Injection (Stage 0 Binaries Only)
let bin_dir = $env.CLAUSE_BIN_DIR
if not ($env.PATH | any { |p| $p == $bin_dir }) {
    $env.PATH = ($env.PATH | prepend $bin_dir)
}

# 5. Dynamic Mise Activation Overlay Generation
let mise_path = ($env.NU_CONFIG_DIR | path join "mise.nu")
^mise activate nu | save $mise_path --force