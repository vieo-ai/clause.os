--- Returns download information for a specific version
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table Version and download information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    local clean_version = version:gsub("^v", "")

    local os_type = RUNTIME.osType:lower()
    local asset_name
    local url

    if os_type == "windows" then
        asset_name = string.format("vscode-win32-x64-%s.zip", clean_version)
        url = string.format("https://update.code.visualstudio.com/%s/win32-x64-archive/stable", clean_version)
    elseif os_type == "darwin" then
        asset_name = "VSCode-darwin-universal.zip"
        url = string.format("https://update.code.visualstudio.com/%s/darwin-universal/stable", clean_version)
    else
        asset_name = string.format("vscode-linux-x64-%s.tar.gz", clean_version)
        url = string.format("https://update.code.visualstudio.com/%s/linux-x64/stable", clean_version)
    end

    return {
        version = clean_version,
        url = url,
        filename = asset_name,
        note = string.format("Seeding VS Code Portable Engine (v%s)...", clean_version),
    }
end