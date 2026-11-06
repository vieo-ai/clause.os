--- Query available versions from upstream ComfyUI repository
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#available-hook
function PLUGIN:Available(ctx)
    local os_type = RUNTIME.osType:lower()
    local is_win = (os_type == "windows")
    local dev_null = is_win and "2>nul" or "2>/dev/null"

    local cmd = string.format("git ls-remote --tags https://github.com/Comfy-Org/ComfyUI.git %s", dev_null)
    local p = io.popen(cmd)
    local versions = {}
    
    if p then
        for line in p:lines() do
            local tag = line:match("refs/tags/(v?[%d%.]+)$")
            if tag then
                table.insert(versions, { version = tag })
            end
        end
        p:close()
    end

    -- If git ls-remote failed or returned empty, provide common fallback versions
    if #versions == 0 then
        table.insert(versions, { version = "v0.43.0" })
    end

    -- Always make latest available
    table.insert(versions, { version = "latest" })
    return versions
end