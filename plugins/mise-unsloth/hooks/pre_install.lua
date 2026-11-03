--- PreInstall hook returning package artifact
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table
function PLUGIN:PreInstall(ctx)
    local version = ctx.version:gsub("^v", "")

    -- Direct download of the wheel or sdist from PyPI
    local http = require("http")
    local json = require("json")

    local resp, err = http.get({
        url = string.format("https://pypi.org/pypi/unsloth/%s/json", version),
    })

    local download_url = nil
    local sha256_hash = nil

    if err == nil and resp.status_code == 200 then
        local data = json.decode(resp.body)
        if data.urls and #data.urls > 0 then
            -- Prefer wheel (.whl), fallback to first available
            for _, file in ipairs(data.urls) do
                if file.url:match("%.whl$") then
                    download_url = file.url
                    sha256_hash = file.digests and file.digests.sha256
                    break
                end
            end
            if not download_url then
                download_url = data.urls[1].url
                sha256_hash = data.urls[1].digests and data.urls[1].digests.sha256
            end
        end
    end

    if not download_url then
        -- Fallback URL to satisfy Mise's fetcher
        download_url = string.format("https://pypi.org/packages/source/u/unsloth/unsloth-%s.tar.gz", version)
    end

    return {
        version = version,
        url = download_url,
        sha256 = sha256_hash,
        note = string.format("Deploying Unsloth AI Engine v%s...", version),
    }
end