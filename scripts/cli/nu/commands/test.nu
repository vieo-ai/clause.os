# scripts/cli/nu/commands/test.nu
# ClauseOS Dynamic Command: 'clause test' / 'start.bat test'

def main [] {
    let project_root = ($env.CLAUSE_PROJECT_ROOT? | default $env.PWD)
    let runner_script = ($project_root | path join "tests" "system" "run_all.nu")

    if ($runner_script | path exists) {
        ^$nu.current-exe $runner_script
    } else {
        error make {
            msg: $"[ClauseOS] Test runner script missing at ($runner_script)"
        }
    }
}