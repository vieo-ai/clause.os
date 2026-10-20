# .config/nushell/env.nu - ClauseOS Nushell Environment Lock

# Resolve ClauseOS root directory reliably from bootloader environment or current directory
let clause_root = if ("CLAUSE_PROJECT_ROOT" in $env) {
    $env.CLAUSE_PROJECT_ROOT
} else if ("CURRENT_FILE" in $env) {
    ($env.CURRENT_FILE | path dirname | path join ".." "..")
} else {
    $env.PWD
}

# Root System Profile Anchors
$env.CLAUSE_PROJECT_ROOT = $clause_root
$env.HOME                = $clause_root
$env.USERPROFILE         = $clause_root

# XDG Base Directories
$env.XDG_CONFIG_HOME = ($clause_root | path join ".config")
$env.XDG_DATA_HOME   = ($clause_root | path join ".local" "share")
$env.XDG_STATE_HOME  = ($clause_root | path join ".local" "state")
$env.XDG_CACHE_HOME  = ($clause_root | path join ".cache")

# Windows Compatibility Environment Variables
$env.APPDATA      = ($clause_root | path join ".local" "appdata")
$env.LOCALAPPDATA = ($clause_root | path join ".local" "share")

# Application Profile Targets
$env.GIT_CONFIG_GLOBAL = ($clause_root | path join ".config" "git" "config")
$env.NU_CONFIG_DIR     = ($clause_root | path join ".config" "nushell")
$env.GH_CONFIG_DIR     = ($clause_root | path join ".config" "gh")

# Isolated Toolchain Directories
$env.MISE_DATA_DIR   = ($clause_root | path join ".cache" "toolchain" "mise")
$env.MISE_CONFIG_DIR = ($clause_root | path join ".cache" "toolchain" "mise-config")
$env.MISE_STATE_DIR  = ($clause_root | path join ".cache" "toolchain" "mise-state")
$env.MISE_CACHE_DIR  = ($clause_root | path join ".cache" "m-cache")

# Enforce .local/bin Prepend
let local_bin = ($clause_root | path join ".local" "bin")
if not ($env.PATH | any { |p| $p == $local_bin }) {
    $env.PATH = ($env.PATH | prepend $local_bin)
}

let mise_path = $nu.default-config-dir | path join mise.nu
^mise activate nu | save $mise_path --force