--- Prepares the download package before installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook
--- @param ctx {version: string} Context
function PLUGIN:PreInstall(ctx)
    local raw_version = ctx.version or "latest"
    local version = tostring(raw_version):gsub("^v", "")

    -- ComfyUI is provisioned hermetically via git/uv inside PostInstall.
    -- Returning version metadata satisfies Mise's lifecycle without downloading external binary archives.
    return {
        version = version
    }
end