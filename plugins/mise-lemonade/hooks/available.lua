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
    local repo_url = "https://api.github.com/repos/lemonade-sdk/lemonade/releases"

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

    local releases = json.decode(resp.body)
    local result = {}

    -- Process tags/releases
    for _, tag_info in ipairs(releases) do
        local tag = tag_info.tag_name or ""
        -- Clean up version string (remove 'v' prefix if present)
        local version = tag:gsub("^v", "")

        -- For releases API, you might want:
        local is_prerelease = tag_info.prerelease or false
        local note = is_prerelease and "pre-release" or nil

        if version ~= "" then
            table.insert(result, {
                version = version,
                note = note, -- Optional: "latest", "lts", "pre-release", etc.
                -- addition = {} -- Optional: additional tools/components
            })
        end
    end

    return result
end