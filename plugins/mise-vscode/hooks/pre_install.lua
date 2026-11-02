--- Returns download information for a specific version
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table Version and download information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    local clean_version = version:gsub("^v", "")

    local os_type = RUNTIME.osType:lower()
    local platform_id

    if os_type == "windows" then
        platform_id = "win32-x64-archive"
    elseif os_type == "darwin" then
        platform_id = "darwin-universal"
    else
        platform_id = "linux-x64"
    end

    return {
        version = clean_version,
        url = string.format("https://update.code.visualstudio.com/%s/%s/stable", clean_version, platform_id),
        note = string.format("Seeding VS Code Portable Engine (v%s)...", clean_version),
    }
end