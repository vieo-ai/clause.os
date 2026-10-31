# scripts/cli/nu/commands/plugin.nu
# ClauseOS Canonical Git Subtree Plugin Manager

def get-prefix [name: string] {
    $"plugins/mise-($name)"
}

def resolve-repo-root [] {
    let check = (^git rev-parse --is-inside-work-tree | complete)
    if $check.exit_code != 0 {
        print $"(ansi red)Error:(ansi reset) Current directory is not a Git repository. Please run from inside your repository root."
        exit 1
    }
    ^git rev-parse --show-toplevel | str trim
}

def resolve-upstream-hash [remote_url: string, branch: string] {
    print $"(ansi cyan)Fetching latest commit hash from ($remote_url) \(($branch)\)...(ansi reset)"
    
    mut target_branch = $branch
    mut ls_output = (^git ls-remote $remote_url $"refs/heads/($target_branch)" | complete)

    if ($ls_output.stdout | str trim | is-empty) {
        # Fallback between main and master if the initial branch does not exist
        $target_branch = if $branch == "main" { "master" } else { "main" }
        print $"(ansi yellow)Branch '($branch)' not found. Checking '($target_branch)' branch...(ansi reset)"
        $ls_output = (^git ls-remote $remote_url $"refs/heads/($target_branch)" | complete)
    }

    if ($ls_output.stdout | str trim | is-empty) {
        print $"(ansi red)Error:(ansi reset) Unable to reach remote repository or find branch '($target_branch)'."
        exit 1
    }

    let full_hash = ($ls_output.stdout | split row -r '\s+' | get 0)
    let short_hash = ($full_hash | str substring 0..6)
    
    { branch: $target_branch, hash: $short_hash }
}

def is-prefix-tracked [prefix: string] {
    if not ($prefix | path exists) {
        return false
    }
    let tracked = (^git ls-files -- $prefix | complete)
    ($tracked.stdout | str trim | is-not-empty)
}

# 1. ADD: Mounts a new subtree
export def add [
    name: string,
    remote_url: string,
    branch: string = "main",
    commit_msg: string = ""
] {
    let repo_root = (resolve-repo-root)
    cd $repo_root

    let prefix = (get-prefix $name)
    if (is-prefix-tracked $prefix) {
        print $"(ansi red)Error:(ansi reset) Subtree prefix '($prefix)' already exists and is tracked. Use 'pull' to update."
        exit 1
    }

    let upstream = (resolve-upstream-hash $remote_url $branch)
    let target_branch = $upstream.branch
    let upstream_hash = $upstream.hash

    let msg = if ($commit_msg | is-not-empty) {
        $"($commit_msg) \(upstream commit: ($upstream_hash)\)"
    } else {
        $"🌱 add: ($prefix) subtree from ($remote_url) @ ($upstream_hash)"
    }

    print $"(ansi cyan)Subtree prefix '($prefix)' not detected in Git. Adding subtree...(ansi reset)"

    let args = [
        "subtree", "add",
        $"--prefix=($prefix)",
        $remote_url,
        $target_branch,
        "--squash",
        "-m", $msg
    ]

    let result = (^git ...$args | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Successfully added subtree at '($prefix)' \(commit: ($upstream_hash)\).(ansi reset)"
    } else {
        print $"(ansi red)Failed to add git subtree.(ansi reset)"
        print $result.stderr
        exit 1
    }
}

# 2. PULL: Updates existing subtree from upstream
export def pull [
    name: string,
    remote_url: string,
    branch: string = "main",
    commit_msg: string = ""
] {
    let repo_root = (resolve-repo-root)
    cd $repo_root

    let prefix = (get-prefix $name)
    if not (is-prefix-tracked $prefix) {
        print $"(ansi red)Error:(ansi reset) Subtree prefix '($prefix)' is not tracked. Use 'add' to import it first."
        exit 1
    }

    let upstream = (resolve-upstream-hash $remote_url $branch)
    let target_branch = $upstream.branch
    let upstream_hash = $upstream.hash

    let msg = if ($commit_msg | is-not-empty) {
        $"($commit_msg) \(upstream commit: ($upstream_hash)\)"
    } else {
        $"🌱 update: ($prefix) subtree from ($remote_url) @ ($upstream_hash)"
    }

    print $"(ansi cyan)Subtree prefix '($prefix)' found. Pulling latest updates from upstream...(ansi reset)"

    let args = [
        "subtree", "pull",
        $"--prefix=($prefix)",
        $remote_url,
        $target_branch,
        "--squash",
        "-m", $msg
    ]

    let result = (^git ...$args | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Successfully updated subtree at '($prefix)' \(commit: ($upstream_hash)\).(ansi reset)"
    } else {
        print $"(ansi red)Failed to pull updates for git subtree.(ansi reset)"
        print $result.stderr
        exit 1
    }
}

# 3. PUSH: Pushes local commits back to the standalone repository
export def push [
    name: string,
    remote_url: string,
    branch: string = "main"
] {
    let repo_root = (resolve-repo-root)
    cd $repo_root

    let prefix = (get-prefix $name)
    if not (is-prefix-tracked $prefix) {
        print $"(ansi red)Error:(ansi reset) Subtree '($prefix)' is not tracked in this repository."
        exit 1
    }

    print $"(ansi cyan)[ClauseOS Subtree](ansi reset) Pushing local commits for ($prefix) to ($remote_url) \(($branch)\)..."

    let args = [
        "subtree", "push",
        $"--prefix=($prefix)",
        $remote_url,
        $branch
    ]

    let result = (^git ...$args | complete)
    let combined_output = $"($result.stdout)\n($result.stderr)"

    if $result.exit_code == 0 {
        if ($combined_output =~ "(?i)everything up-to-date") {
            print $"(ansi yellow)Notice:(ansi reset) '($prefix)' is already in sync with ($remote_url) \(($branch)\)."
        } else {
            print $"(ansi green)Successfully pushed commits from '($prefix)' to ($remote_url).(ansi reset)"
        }
    } else {
        print $"(ansi red)Failed to push subtree commits.(ansi reset)"
        print $result.stderr
        exit 1
    }
}

def main [action?: string, ...args: string] {
    match $action {
        "add" => {
            if ($args | length) < 2 {
                print "Usage: cx plugin add <name> <remote-url> [branch] [commit-message]"
                return
            }
            let branch = if ($args | length) >= 3 { $args | get 2 } else { "main" }
            let msg    = if ($args | length) >= 4 { $args | get 3 } else { "" }
            add ($args | get 0) ($args | get 1) $branch $msg
        },
        "pull" => {
            if ($args | length) < 2 {
                print "Usage: cx plugin pull <name> <remote-url> [branch] [commit-message]"
                return
            }
            let branch = if ($args | length) >= 3 { $args | get 2 } else { "main" }
            let msg    = if ($args | length) >= 4 { $args | get 3 } else { "" }
            pull ($args | get 0) ($args | get 1) $branch $msg
        },
        "push" => {
            if ($args | length) < 2 {
                print "Usage: cx plugin push <name> <remote-url> [branch]"
                return
            }
            let branch = if ($args | length) >= 3 { $args | get 2 } else { "main" }
            push ($args | get 0) ($args | get 1) $branch
        },
        _ => {
            print "ClauseOS Plugin Subtree Manager"
            print "--------------------------------"
            print "Usage:"
            print "  cx plugin add  <name> <remote-url> [branch] [msg] - Add a new plugin subtree"
            print "  cx plugin pull <name> <remote-url> [branch] [msg] - Pull upstream changes into subtree"
            print "  cx plugin push <name> <remote-url> [branch]       - Push local subtree commits upstream"
        }
    }
}