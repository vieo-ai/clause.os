# scripts/cli/nu/core/boot.nu
# Stage 1 Environment Setup & Boot Dispatcher for ClauseOS

# 1. Resolve Project Root (4 levels up from scripts/cli/nu/core/boot.nu)
let current_dir = ($env.FILE_PWD? | default $env.PWD)
let resolved_root = ($current_dir | path join ".." ".." ".." | path expand)

$env.CLAUSE_PROJECT_ROOT = ($env.CLAUSE_PROJECT_ROOT? | default $resolved_root)

# 2. Source Base Environment Config from .config/nushell/env.nu
const shell_env = "../../../../.config/nushell/env.nu"
if ($shell_env | path exists) {
    source $shell_env
}

# 3. Resolve Compiled Jet Shipment Entrypoint
def get-jet-entrypoint [] {
    let project_root = $env.CLAUSE_PROJECT_ROOT
    let shipment_dir = ($project_root | path join "packages" "carrier_jet" "build" "erlang-shipment")
    
    let is_windows = (($nu.os-info.name | str lowercase) == "windows")
    let script_name = if $is_windows { "entrypoint.ps1" } else { "entrypoint.sh" }
    let target = ($shipment_dir | path join $script_name)

    if ($target | path exists) {
        $target
    } else {
        null
    }
}

# 4. Global CLI Router Function ('clause' command)
def --env clause [cmd: string = "", ...args: string] {
    let project_root = $env.CLAUSE_PROJECT_ROOT
    let mod_nu = ($project_root | path join "scripts" "cli" "nu" "mod.nu")
    let nu_bin = $nu.current-exe

    if ($cmd == "jet") {
        let entrypoint = (get-jet-entrypoint)
        if $entrypoint != null {
            let is_windows = (($nu.os-info.name | str lowercase) == "windows")
            if $is_windows {
                ^pwsh -NoProfile -ExecutionPolicy Bypass -File $entrypoint ...$args
            } else {
                ^$entrypoint ...$args
            }
        } else {
            print $"(ansi red)Error:(ansi reset) Carrier Jet shipment not found. Run 'gleam export erlang-shipment' inside packages/carrier_jet first."
        }
    } else if ($cmd | is-empty) {
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

alias carrier = clause
alias cx = clause