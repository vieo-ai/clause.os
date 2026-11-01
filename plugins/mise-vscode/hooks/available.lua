--- Returns a list of available versions for the tool
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#available-hook
--- @param ctx {args: string[]} Context (args = user arguments)
--- @return table[] List of available versions
function PLUGIN:Available(ctx)
    local http = require("http")
    local json = require("json")

    -- Example 1: GitHub Tags API (most common)
    -- Replace <GITHUB_USER>/<GITHUB_REPO> with your tool's repository
    -- local repo_url = "https://api.github.com/repos/<GITHUB_USER>/<GITHUB_REPO>/tags"

    -- Example 2: GitHub Releases API (for tools that use GitHub releases)
    local repo_url = "https://api.github.com/repos/microsoft/vscode/tags"

    -- For api.github.com requests, mise attaches a configured GitHub token automatically.
    -- Do not read tokens or construct Authorization headers in the plugin. See README.md
    -- for the supported private-repository setup.
    local resp, err = http.get({
        url = repo_url,
    })

    if err ~= nil then
        error("Failed to fetch versions: " .. err)
    end
    if resp.status_code ~= 200 then
        error("GitHub API returned status " .. resp.status_code .. ": " .. resp.body)
    end

    local tags = json.decode(resp.body)
    local result = {}

    -- Process tags/releases
    for _, tag_info in ipairs(tags) do
        local tag = tag_info.name or ""
        -- Clean up version string (remove 'v' prefix if present)
        local version = tag:gsub("^v", "")

        -- Filter to standard semantic version tags (exclude custom release tags)
        if version:match("^%d+%.%d+%.%d+$") then
            table.insert(result, {
                version = version,
                note = nil,
            })
        end
    end

    return result
end