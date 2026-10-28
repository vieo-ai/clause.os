# scripts/cli/nu/config/config.nu - ClauseOS Nushell UI & Shell Overlay Config

# 1. Source Mise overlay using a static relative path resolved at parse time
source ./mise.nu

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