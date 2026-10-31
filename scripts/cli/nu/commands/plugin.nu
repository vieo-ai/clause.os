# scripts/cli/nu/commands/plugin.nu
# ClauseOS Git Subtree Plugin Manager

def get-prefix [name: string] {
    # CRITICAL: git-subtree requires pure forward slashes and no leading './'
    $"plugins/mise-($name)"
}

def ensure-clean-tree [] {
    let status = (^git status --porcelain | str trim)
    if ($status | is-not-empty) {
        print $"(ansi red)Error:(ansi reset) Working directory is dirty. Commit or stash changes before running subtree operations."
        exit 1
    }
}

def add [
    name: string,
    repo_url: string,
    branch: string = "main"
] {
    ensure-clean-tree

    let prefix = (get-prefix $name)
    let remote_name = $"plugin-($name)"

    # Hard safety check to prevent root clobbering
    if ($prefix | is-empty) or ($prefix == ".") or ($prefix == "/") {
        print $"(ansi red)Fatal:(ansi reset) Invalid target prefix '($prefix)'. Aborting to protect repository root."
        exit 1
    }

    print $"(ansi cyan)[ClauseOS Subtree](ansi reset) Target Directory: ($prefix)"
    print $"(ansi cyan)[ClauseOS Subtree](ansi reset) Remote: ($remote_name) -> ($repo_url)"

    let remotes = (^git remote | lines)
    if not ($remote_name in $remotes) {
        ^git remote add -f $remote_name $repo_url
    } else {
        ^git remote set-url $remote_name $repo_url
        ^git fetch $remote_name
    }

    # --prefix must be passed as two separate arguments, never --prefix=...
    try {
        ^git subtree add --prefix $prefix $remote_name $branch --squash -m $"feat(plugins): import ($name) plugin subtree"
        print $"(ansi green)Success:(ansi reset) Plugin ($name) mounted at ($prefix)"
    } catch { |err|
        print $"(ansi red)Error:(ansi reset) git subtree add failed."
        print $err
    }
}

def push [
    name: string,
    remote: string = "",
    branch: string = "main"
] {
    let prefix = (get-prefix $name)
    let target = if ($remote | is-empty) { $"plugin-($name)" } else { $remote }

    if not ($prefix | path exists) {
        print $"(ansi red)Error:(ansi reset) Prefix ($prefix) does not exist."
        exit 1
    }

    print $"(ansi cyan)[ClauseOS Subtree](ansi reset) Pushing commits from ($prefix) to ($target)/($branch)..."
    try {
        ^git subtree push --prefix $prefix $target $branch
        print $"(ansi green)Success:(ansi reset) ($name) plugin upstream is in sync."
    } catch { |err|
        print $"(ansi red)Error:(ansi reset) git subtree push failed."
        print $err
    }
}

def pull [
    name: string,
    remote: string = "",
    branch: string = "main"
] {
    ensure-clean-tree

    let prefix = (get-prefix $name)
    let target = if ($remote | is-empty) { $"plugin-($name)" } else { $remote }

    print $"(ansi cyan)[ClauseOS Subtree](ansi reset) Pulling commits from ($target)/($branch) into ($prefix)..."
    try {
        ^git subtree pull --prefix $prefix $target $branch --squash -m $"chore(plugins): sync ($name) from upstream"
        print $"(ansi green)Success:(ansi reset) ($prefix) updated from ($target)."
    } catch { |err|
        print $"(ansi red)Error:(ansi reset) git subtree pull failed."
        print $err
    }
}

def main [action?: string, ...args: string] {
    match $action {
        "add" => {
            if ($args | length) < 2 {
                print "Usage: cx plugin add <name> <repo-url> [branch]"
                return
            }
            let branch = if ($args | length) >= 3 { $args | get 2 } else { "main" }
            add ($args | get 0) ($args | get 1) $branch
        },
        "push" => {
            if ($args | length) < 1 {
                print "Usage: cx plugin push <name> [remote] [branch]"
                return
            }
            let remote = if ($args | length) >= 2 { $args | get 1 } else { "" }
            let branch = if ($args | length) >= 3 { $args | get 2 } else { "main" }
            push ($args | get 0) $remote $branch
        },
        "pull" => {
            if ($args | length) < 1 {
                print "Usage: cx plugin pull <name> [remote] [branch]"
                return
            }
            let remote = if ($args | length) >= 2 { $args | get 1 } else { "" }
            let branch = if ($args | length) >= 3 { $args | get 2 } else { "main" }
            pull ($args | get 0) $remote $branch
        },
        _ => {
            print "ClauseOS Plugin Subtree Manager"
            print "--------------------------------"
            print "Usage:"
            print "  cx plugin add <name> <repo-url> [branch]  - Mount standalone repo as subtree"
            print "  cx plugin push <name> [remote] [branch]   - Push subtree commits to standalone repo"
            print "  cx plugin pull <name> [remote] [branch]   - Pull updates from standalone repo"
        }
    }
}