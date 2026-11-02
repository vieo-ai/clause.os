--- Returns download information for a specific version
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table Version and download information
function PLUGIN:PreInstall(ctx)
    local http = require("http")
    local json = require("json")

    local clean_version = ctx.version:gsub("^v", "")
    local os_type = RUNTIME.osType:lower()

    -- 1. Detect platform identifier
    local platform_id
    if os_type == "windows" then
        platform_id = "win32-x64-archive"
    elseif os_type == "darwin" then
        platform_id = "darwin-universal"
    else
        platform_id = "linux-x64"
    end

    -- 2. Query Microsoft's release endpoint to get the direct CDN URL ending in .zip / .tar.gz
    local meta_url = string.format("https://update.code.visualstudio.com/api/update/%s/stable/%s", platform_id, clean_version)
    local resp, err = http.get({ url = meta_url })

    if err ~= nil or resp.status_code ~= 200 then
        error(string.format("Failed to resolve VS Code download URL for version %s on %s", clean_version, os_type))
    end

    local data = json.decode(resp.body)
    if not data or not data.url then
        error(string.format("Invalid response payload from VS Code API for version %s", clean_version))
    end

    -- data.url is the direct Azure CDN URL ending in .zip / .tar.gz
    return {
        version = clean_version,
        url = data.url,
        sha256 = data.sha256hash,
        note = string.format("Seeding VS Code Portable Engine (v%s)...", clean_version),
    }
end