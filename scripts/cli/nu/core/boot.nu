# scripts/cli/nu/core/boot.nu
# Stage 1 Environment Setup & Boot Dispatcher for ClauseOS

# 1. Resolve Project Root relative to boot.nu (4 levels up from scripts/cli/nu/core/)
let script_path = if ("CURRENT_FILE" in $env) { $env.CURRENT_FILE } else { $env.FILE_PWD? | default $env.PWD }
let script_dir = ($script_path | path dirname)
let resolved_root = ($script_dir | path join ".." ".." ".." "..")

$env.CLAUSE_PROJECT_ROOT = ($env.CLAUSE_PROJECT_ROOT? | default $resolved_root)

# 2. Source Base Environment Config from .config/nushell/env.nu
const shell_env = "../../../../.config/nushell/env.nu"
if ($shell_env | path exists) {
    source $shell_env
}

# 3. Global CLI Router Function ('clause' command)
def --env clause [cmd: string = "", ...args: string] {
    let project_root = $env.CLAUSE_PROJECT_ROOT
    let mod_nu = ($project_root | path join "scripts" "cli" "nu" "mod.nu")
    let nu_bin = $nu.current-exe
    
    if ($cmd | is-empty) {
        ^$nu_bin $mod_nu
    } else {
        ^$nu_bin $mod_nu $cmd ...$args
    }
}

# 4. Interactive Prompt Setup
$env.PROMPT_COMMAND = {||
    let relative_pwd = ($env.PWD | str replace $env.CLAUSE_PROJECT_ROOT ".")
    $"(ansi cyan)[ClauseOS](ansi reset) (ansi yellow)($relative_pwd)(ansi reset) > "
}