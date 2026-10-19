# scripts/console/nu/core/env.nu
# Stage 1 Environment Setup for ClauseOS Cockpit

# 1. Resolve Project Root
let script_root = ($env.FILE_PWD? | default ($env.PWD))
$env.CLAUSE_PROJECT_ROOT = ($env.CLAUSE_PROJECT_ROOT? | default $script_root)

# 2. Source Base Environment Config (Parse-Time Relative Path)
const shell_env = "../../../../config/shell/env.nu"
if ($shell_env | path exists) {
    source $shell_env
}

# 3. Compiler Overrides
$env.CC  = "zig cc"
$env.CXX = "zig c++"

# 4. Global CLI Router Function ('clause' command)
def --env clause [cmd: string = "", ...args: string] {
    let project_root = $env.CLAUSE_PROJECT_ROOT
    let mod_nu = ($project_root | path join "scripts" "console" "nu" "mod.nu")
    let nu_bin = $nu.current-exe
    
    if ($cmd | is-empty) {
        ^$nu_bin $mod_nu
    } else {
        ^$nu_bin $mod_nu $cmd ...$args
    }
}

# 5. Interactive Prompt Setup
$env.PROMPT_COMMAND = {||
    let relative_pwd = ($env.PWD | str replace $env.CLAUSE_PROJECT_ROOT ".")
    $"(ansi cyan)[ClauseOS](ansi reset) (ansi yellow)($relative_pwd)(ansi reset) > "
}