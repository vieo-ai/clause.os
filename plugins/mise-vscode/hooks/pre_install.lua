--- Returns download information for a specific version
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table Version and download information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    -- ctx.runtimeVersion contains the full version string if needed

    local clean_version = version:gsub("^v", "")

    -- Exact translation of installer_vscode.ps1:
    -- Windows: https://update.code.visualstudio.com/${Version}/win32-x64-archive/stable
    -- macOS:   https://update.code.visualstudio.com/${Version}/darwin-universal/stable
    -- Linux:   https://update.code.visualstudio.com/${Version}/linux-x64/stable
    local url
    local os_type = RUNTIME.osType:lower()

    if os_type == "windows" then
        url = string.format("https://update.code.visualstudio.com/%s/win32-x64-archive/stable", clean_version)
    elseif os_type == "darwin" then
        url = string.format("https://update.code.visualstudio.com/%s/darwin-universal/stable", clean_version)
    else
        url = string.format("https://update.code.visualstudio.com/%s/linux-x64/stable", clean_version)
    end

    -- Optional: Fetch checksum for verification
    -- local sha256 = fetch_checksum(version) -- Implement if checksums are available

    return {
        version = clean_version,
        url = url,
        note = string.format("Seeding VS Code Portable Engine (v%s)...", clean_version),
    }
end

-- Helper function for platform detection (uncomment and modify as needed)
--[[
local function get_platform()
    local os_name = RUNTIME.osType:lower()
    local arch = RUNTIME.archType
    return os_name
end
--]]