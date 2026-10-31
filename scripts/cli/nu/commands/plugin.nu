# scripts/cli/nu/commands/plugin_sync.nu
# ClauseOS Git Subtree Plugin Synchronizer

def get-prefix [name: string] {
    $".mise/plugins/($name)"
}

# Add a new plugin repository as a git subtree
export def "main add" [
    name: string,         # Plugin name (e.g. 'lemonade')
    repo_url: string,     # Git remote repository URL
    --branch: string = "main" # Remote branch
] {
    let prefix = (get-prefix $name)
    print $"(ansi cyan)[ClauseOS Subtree](ansi reset) Attaching ($name) from ($repo_url)..."

    # 1. Add remote if it doesn't already exist
    let remotes = (^git remote | lines)
    let remote_name = $"plugin-($name)"
    if not ($remote_name in $remotes) {
        ^git remote add -f $remote_name $repo_url
    } else {
        ^git remote set-url $remote_name $repo_url
        ^git fetch $remote_name
    }

    # 2. Add subtree with squash
    try {
        ^git subtree add --prefix=$prefix $remote_name $branch --squash -m $"feat(plugins): import ($name) plugin subtree"
        print $"(ansi green)Success:(ansi reset) Plugin ($name) mounted at ($prefix)"
    } catch { |err|
        print $"(ansi red)Error:(ansi reset) Failed to add subtree. Ensure working tree is clean."
    }
}

# Push changes from local monorepo back to the standalone plugin repository
export def "main push" [
    name: string,         # Plugin name (e.g. 'lemonade')
    --remote: string,     # Optional remote name or URL
    --branch: string = "main" # Remote target branch
] {
    let prefix = (get-prefix $name)
    let target = if ($remote | is-empty) { $"plugin-($name)" } else { $remote }

    print $"(ansi cyan)[ClauseOS Subtree](ansi reset) Pushing local commits for ($prefix) to ($target)/($branch)..."

    try {
        ^git subtree push --prefix=$prefix $target $branch
        print $"(ansi green)Success:(ansi reset) ($name) plugin upstream is in sync."
    } catch { |err|
        print $"(ansi red)Error:(ansi reset) Failed to push subtree to ($target)."
    }
}

# Pull latest commits from the standalone repository into the monorepo
export def "main pull" [
    name: string,         # Plugin name (e.g. 'lemonade')
    --remote: string,     # Optional remote name or URL
    --branch: string = "main" # Remote source branch
] {
    let prefix = (get-prefix $name)
    let target = if ($remote | is-empty) { $"plugin-($name)" } else { $remote }

    print $"(ansi cyan)[ClauseOS Subtree](ansi reset) Pulling latest commits from ($target)/($branch) into ($prefix)..."

    try {
        ^git subtree pull --prefix=$prefix $target $branch --squash -m $"chore(plugins): sync ($name) from upstream"
        print $"(ansi green)Success:(ansi reset) ($prefix) updated from ($target)."
    } catch { |err|
        print $"(ansi red)Error:(ansi reset) Failed to pull subtree."
    }
}

# Default entry: display instructions or status
export def main [] {
    print "ClauseOS Plugin Subtree Manager"
    print "--------------------------------"
    print "Usage:"
    print "  cx plugin add <name> <repo-url>   - Add standalone repo as local subtree"
    print "  cx plugin push <name>             - Push local modifications to standalone repo"
    print "  cx plugin pull <name>             - Pull updates from standalone repo"
}