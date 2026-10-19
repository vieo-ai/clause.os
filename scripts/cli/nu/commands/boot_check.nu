# scripts/console/nu/commands/boot_check.nu
# Startup Verification Engine for ClauseOS

def main [] {
    let root = ($env.CLAUSE_PROJECT_ROOT? | default ($env.PWD))
    
    print $"(ansi green)  DONE(ansi reset)  Welcome to the ClauseOS Workbench."
    print $"(ansi dark_gray)        Hermetic Root: ($root)(ansi reset)"
    print ""

    # Verify Tier 1 System Package Manager
    if $nu.os-info.name == "windows" {
        let scoop_shim = ($root | path join ".cache" "toolchain" "scoop" "shims" "scoop.ps1")
        if ($scoop_shim | path exists) {
            print $"(ansi cyan)  INFO(ansi reset)  Tier 1 Engine: Scoop is online."
        }
    } else {
        let brew_bin = ($root | path join ".cache" "toolchain" "brew" "bin" "brew")
        if ($brew_bin | path exists) {
            print $"(ansi cyan)  INFO(ansi reset)  Tier 1 Engine: Homebrew is online."
        }
    }

    # Verify Tier 2 Workspace SDK Manager
    if (which mise | is-not-empty) {
        print $"(ansi cyan)  INFO(ansi reset)  Tier 2 Engine: Mise is online."
    }
}