#!/usr/bin/env nu

def assert [condition: bool, message: string] {
    if not $condition {
        print $"(ansi red) [FAIL] ($message)(ansi reset)"
        exit 1
    } else {
        print $"(ansi green) [PASS] ($message)(ansi reset)"
    }
}

let root = ($env.FILE_PWD | path join ".." ".." | path expand)
let expected_home = ($root | path join ".home")[cite: 6, 18]
let env_script = ($root | path join "scripts" "cli" "nu" "config" "env.nu")[cite: 14, 18]

nu -n --env-config $env_script -c $"
    let root = '($root)'
    let expected_home = '($expected_home)'
    let is_windows = (($nu.os-info.name | str lowercase) == 'windows')[cite: 6, 18]

    assert ($env.HOME == $expected_home) 'Nushell HOME points to .home'[cite: 6, 18]
    assert ($env.USERPROFILE == $expected_home) 'Nushell USERPROFILE points to .home'[cite: 6, 18]

    if $is_windows {
        assert ($env.LOCALAPPDATA == ($expected_home | path join 'AppData' 'Local')) 'Windows LOCALAPPDATA location'[cite: 6, 18]
    } else {
        assert ($env.XDG_CONFIG_HOME == ($expected_home | path join '.config')) 'POSIX XDG_CONFIG_HOME location'[cite: 6, 18]
    }

    let bin_dir = $env.CLAUSE_BIN_DIR[cite: 19, 31]
    assert (($env.PATH | first) == $bin_dir) 'CLAUSE_BIN_DIR is prepended to PATH'[cite: 19, 31]
    assert (not ($env.PATH | any { |p| $p =~ 'mise.*shims' })) 'PATH contains no Mise shims'[cite: 29, 31]
"