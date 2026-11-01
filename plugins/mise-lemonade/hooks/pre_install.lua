--- Returns download information for a specific version
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table Version and download information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    -- ctx.runtimeVersion contains the full version string if needed

    -- Example 1: Simple binary download
    -- local url = "https://github.com/<GITHUB_USER>/<GITHUB_REPO>/releases/download/v" .. version .. "/<TOOL>-linux-amd64"

    -- Example 2: Platform-specific binary
    -- local platform = get_platform() -- Uncomment the helper function below
    -- local url = "https://github.com/<GITHUB_USER>/<GITHUB_REPO>/releases/download/v" .. version .. "/<TOOL>-" .. platform

    -- Example 3: Archive (tar.gz, zip) - mise will extract automatically
    -- local url = "https://github.com/<GITHUB_USER>/<GITHUB_REPO>/releases/download/v" .. version .. "/<TOOL>-" .. version .. "-linux-amd64.tar.gz"

    -- Example 4: Raw file from repository
    -- local url = "https://raw.githubusercontent.com/<GITHUB_USER>/<GITHUB_REPO>/" .. version .. "/bin/<TOOL>"

    local clean_version = version:gsub("^v", "")
    local tag = "v" .. clean_version

    -- Faithful mapping to installer_lemonade.ps1 asset matrix
    local asset_name
    local os_type = RUNTIME.osType:lower()

    if os_type == "windows" then
        asset_name = string.format("lemonade-embeddable-%s-windows-x64.zip", clean_version)
    elseif os_type == "darwin" then
        asset_name = string.format("lemonade-embeddable-%s-macos-arm64.tar.gz", clean_version)
    else
        asset_name = string.format("lemonade-embeddable-%s-ubuntu-x64.tar.gz", clean_version)
    end

    local url = string.format(
        "https://github.com/lemonade-sdk/lemonade/releases/download/%s/%s",
        tag,
        asset_name
    )

    -- Optional: Fetch checksum for verification
    -- local sha256 = fetch_checksum(version) -- Implement if checksums are available

    return {
        version = clean_version,
        url = url,
        -- sha256 = sha256, -- Optional but recommended for security
        note = string.format("Seeding Lemonade GPU Engine (%s)...", tag),
        -- addition = { -- Optional: download additional components
        --     {
        --         name = "component",
        --         url = "https://example.com/component.tar.gz"
        --     }
        -- }
    }
end

-- Helper function for platform detection (uncomment and modify as needed)
--[[
local function get_platform()
    -- RUNTIME object is provided by mise/vfox
    -- RUNTIME.osType: "Windows", "Linux", "Darwin"
    -- RUNTIME.archType: "amd64", "386", "arm64", etc.

    local os_name = RUNTIME.osType:lower()
    local arch = RUNTIME.archType

    -- Map to your tool's platform naming convention
    -- Adjust these mappings based on how your tool names its releases
    local platform_map = {
        ["darwin"] = {
            ["amd64"] = "darwin-amd64",
            ["arm64"] = "darwin-arm64",
        },
        ["linux"] = {
            ["amd64"] = "linux-amd64",
            ["arm64"] = "linux-arm64",
            ["386"] = "linux-386",
        },
        ["windows"] = {
            ["amd64"] = "windows-amd64",
            ["386"] = "windows-386",
        }
    }

    local os_map = platform_map[os_name]
    if os_map then
        return os_map[arch] or "linux-amd64"  -- fallback
    end

    -- Default fallback
    return "linux-amd64"
end
--]]