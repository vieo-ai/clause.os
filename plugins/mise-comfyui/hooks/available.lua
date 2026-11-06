--- Query available versions from upstream ComfyUI repository
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#available-hook
function PLUGIN:Available(ctx)
    local p = io.popen("git ls-remote --tags https://github.com/Comfy-Org/ComfyUI.git 2>/dev/null")
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

    -- Always make latest available
    table.insert(versions, { version = "latest" })
    return versions
end