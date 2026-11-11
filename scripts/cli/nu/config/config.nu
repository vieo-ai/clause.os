# scripts/cli/nu/config/config.nu - ClauseOS Nushell UI & Shell Overlay Config

# 1. Source Mise overlay using a static relative path resolved at parse time
source ./mise.nu

# ==============================================================================
# HERMETIC SHELL HOOKS & NAVIGATION
# ==============================================================================
# Preserve the built-in directory navigation command before shadowing it
alias nu_cd = cd

# Redirect bare 'cd' or tilde paths (~/...) strictly to the hermetic root .home
def --env cd [path?: string] {
    let target = if ($path | is-empty) or ($path == "~") {
        $env.CLAUSE_HOME
    } else if ($path | str starts-with "~/") or ($path | str starts-with "~\\") {
        let rel_path = ($path | str substring 2..)
        ($env.CLAUSE_HOME | path join $rel_path)
    } else {
        $path
    }

    nu_cd $target
}

# 2. Re-establish top priority for ClauseOS hermetic binary directory
let hermetic_bin = ($env.CLAUSE_BIN_DIR | path expand)
$env.PATH = (
    $env.PATH 
    | where { |p| if ($p | path exists) { ($p | path expand) != $hermetic_bin } else { $p != $hermetic_bin } } 
    | prepend $hermetic_bin
)

# 3. Configure Shell Settings
$env.config = ($env.config | merge {
    show_banner: false
    table: {
        mode: rounded
    }
})