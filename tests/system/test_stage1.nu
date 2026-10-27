# tests/system/test_stage1.nu
use std assert

export def main [] {
    print "  [+] Testing Stage 1: Portable Apps & AI Components..."

    let project_root = ($env.CLAUSE_PROJECT_ROOT? | default $env.PWD)
    let is_windows = (($nu.os-info.name | str lowercase) == "windows")
    let exe_ext = if $is_windows { ".exe" } else { "" }

    # Resolve apps directory from canonical env or derive from .home
    let default_apps = if $is_windows {
        $project_root | path join ".home" "AppData" "Local" "Programs" "apps"
    } else {
        $project_root | path join ".home" ".local" "apps"
    }
    let app_dir = ($env.CLAUSE_APPS_DIR? | default $default_apps)

    # 1. Check Lemonade GPU Engine
    let lemonade_dir = ($app_dir | path join "lemonade")
    assert ($lemonade_dir | path exists) "[Stage 1 Failure] Lemonade GPU directory missing"
    assert ((ls $lemonade_dir | length) > 0) "[Stage 1 Failure] Lemonade GPU directory is empty"

    # 2. Check FastFlowLM NPU Engine (Linux & Windows only)
    if ($nu.os-info.name != "macos") {
        let fastflow_dir = ($app_dir | path join "fastflowlm")
        assert ($fastflow_dir | path exists) "[Stage 1 Failure] FastFlowLM directory missing"
        assert ((ls $fastflow_dir | length) > 0) "[Stage 1 Failure] FastFlowLM directory is empty"
    }

    # 3. Check Agent Package Manager (APM)
    let apm_bin = ($app_dir | path join "apm" $"apm($exe_ext)")
    assert ($apm_bin | path exists) $"[Stage 1 Failure] APM binary missing at ($apm_bin)"

    # 4. Check VS Code Portable
    let vscode_dir = ($app_dir | path join "vscode")
    let vscode_data = ($vscode_dir | path join "data")
    assert ($vscode_dir | path exists) "[Stage 1 Failure] VS Code directory missing"
    assert ($vscode_data | path exists) "[Stage 1 Failure] VS Code portable 'data' folder missing"

    print "  [✓] Stage 1 Portable Apps Verified Successfully."
}