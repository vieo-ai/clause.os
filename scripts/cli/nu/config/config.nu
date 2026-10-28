# scripts/cli/nu/config/config.nu - ClauseOS Nushell UI & Shell Overlay Config
use mise.nu

let mise_path = ($env.NU_CONFIG_DIR | path join "mise.nu")
if ($mise_path | path exists) {
    source $mise_path
}

# Re-establish top priority for ClauseOS hermetic binary directory
let hermetic_bin = ($env.CLAUSE_BIN_DIR | path expand)
$env.PATH = ($env.PATH | where { |p| ($p | path expand) != $hermetic_bin } | prepend $hermetic_bin)

$env.config = {
    show_banner: false
    table: {
        mode: rounded
    }
}