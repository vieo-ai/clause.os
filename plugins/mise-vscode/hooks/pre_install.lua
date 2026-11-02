--- Returns download information for a specific version
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table Version and download information
function PLUGIN:PreInstall(ctx)
    local http = require("http")

    local version = ctx.version
    local clean_version = version:gsub("^v", "")

    local os_type = RUNTIME.osType:lower()
    local redirect_url

    if os_type == "windows" then
        redirect_url = string.format("https://update.code.visualstudio.com/%s/win32-x64-archive/stable", clean_version)
    elseif os_type == "darwin" then
        redirect_url = string.format("https://update.code.visualstudio.com/%s/darwin-universal/stable", clean_version)
    else
        redirect_url = string.format("https://update.code.visualstudio.com/%s/linux-x64/stable", clean_version)
    end

    -- Query Microsoft's endpoint to resolve the 302 redirect to the direct CDN archive URL
    local resp, err = http.head({
        url = redirect_url,
    })

    local final_url = redirect_url
    if err == nil and resp ~= nil then
        -- Check redirect Location header if not followed automatically
        if resp.headers and resp.headers["location"] then
            final_url = resp.headers["location"]
        elseif resp.headers and resp.headers["Location"] then
            final_url = resp.headers["Location"]
        end
    end

    return {
        version = clean_version,
        url = final_url,
        note = string.format("Seeding VS Code Portable Engine (v%s)...", clean_version),
    }
end