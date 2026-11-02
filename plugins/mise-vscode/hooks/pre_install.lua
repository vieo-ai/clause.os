--- Returns download information for a specific version
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table Version and download information
function PLUGIN:PreInstall(ctx)
    local http = require("http")
    local json = require("json")

    local version = ctx.version
    local clean_version = version:gsub("^v", "")

    -- Map platform to Microsoft VS Code API platform identifier
    local os_type = RUNTIME.osType:lower()
    local platform_id
    if os_type == "windows" then
        platform_id = "win32-x64-archive"
    elseif os_type == "darwin" then
        platform_id = "darwin-universal"
    else
        platform_id = "linux-x64"
    end

    -- Query the official update metadata endpoint which returns the direct archive URL
    local meta_url = string.format("https://update.code.visualstudio.com/api/update/%s/stable/%s", platform_id, clean_version)
    local resp, err = http.get({
        url = meta_url,
    })

    local download_url = nil
    local sha256_hash = nil

    if err == nil and resp.status_code == 200 then
        local data = json.decode(resp.body)
        if data and data.url then
            download_url = data.url
            sha256_hash = data.sha256hash
        end
    end

    -- Fallback to direct stable route if metadata API is unavailable
    if not download_url then
        download_url = string.format("https://update.code.visualstudio.com/%s/%s/stable", clean_version, platform_id)
    end

    return {
        version = clean_version,
        url = download_url,
        sha256 = sha256_hash,
        note = string.format("Seeding VS Code Portable Engine (v%s)...", clean_version),
    }
end