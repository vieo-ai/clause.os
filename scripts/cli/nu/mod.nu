# scripts/cli/nu/mod.nu
# Universal Command Router for ClauseOS
export use commands/banner.nu

def main [cmd?: string, ...args: string] {
    if ($cmd | is-empty) or ($cmd == "list") or ($cmd == "--help") or ($cmd == "-h") {
        show-help
        return
    }

    let root = ($env.CLAUSE_PROJECT_ROOT? | default ($env.PWD))
    let normalized = ($cmd | str replace -a ":" "_")
    let nu_bin = $nu.current-exe

    # 1. Search Nushell Engine: scripts/cli/nu/commands/<command>.nu
    let nu_script = ($root | path join "scripts" "cli" "nu" "commands" $"($normalized).nu")
    if ($nu_script | path exists) {
        ^$nu_bin $nu_script ...$args
        return
    }

    # 2. Search TypeScript Engine (Bun): scripts/cli/ts/commands/<command>.ts
    let ts_script = ($root | path join "scripts" "cli" "ts" "commands" $"($normalized).ts")
    if ($ts_script | path exists) {
        ^bun run $ts_script ...$args
        return
    }

    # 3. Search Python Engine: scripts/cli/py/commands/<command>.py
    let py_script = ($root | path join "scripts" "cli" "py" "commands" $"($normalized).py")
    if ($py_script | path exists) {
        ^python $py_script ...$args
        return
    }

    # 4. Search PowerShell Engine: scripts/cli/ps1/commands/<command>.ps1
    let ps_script = ($root | path join "scripts" "cli" "ps1" "commands" $"($normalized).ps1")
    if ($ps_script | path exists) {
        let pwsh_bin = if $nu.os-info.name == "windows" {
            ($root | path join ".local" "bin" "pwsh.exe")
        } else {
            ($root | path join ".local" "bin" "pwsh")
        }
        
        let pwsh_cmd = if ($pwsh_bin | path exists) { $pwsh_bin } else { "powershell" }
        ^$pwsh_cmd -NoProfile -ExecutionPolicy Bypass -File $ps_script ...$args
        return
    }

    # 5. Search POSIX/Bash Engine: scripts/cli/sh/commands/<command>.sh
    let sh_script = ($root | path join "scripts" "cli" "sh" "commands" $"($normalized).sh")
    if ($sh_script | path exists) {
        let bash_cmd = "bash"
        ^$bash_cmd $sh_script ...$args
        return
    }

    # 6. Search Gleam Control Plane Engine
    let gleam_dir = ($root | path join "packages" "clause_cli")
    if ($gleam_dir | path exists) {
        try {
            gleam run --project $gleam_dir -- $cmd ...$args
            return
        } catch {}
    }

    print $"(ansi red)FAIL(ansi reset) Command [($cmd)] not found in .nu, .ts, .py, .ps1, .sh, or .gleam formats."
}

def show-help [] {
    print $"(ansi cyan_bold)ClauseOS Workbench — Universal Console Engine(ansi reset)"
    print "Usage: clause <command> [...args]\n"
    print "Engine Search Routes:"
    print "  • scripts/cli/nu/commands/*.nu"
    print "  • scripts/cli/ts/commands/*.ts"
    print "  • scripts/cli/py/commands/*.py"
    print "  • scripts/cli/ps1/commands/*.ps1"
    print "  • scripts/cli/sh/commands/*.sh"
    print "  • packages/clause_cli/ (.gleam)"
}