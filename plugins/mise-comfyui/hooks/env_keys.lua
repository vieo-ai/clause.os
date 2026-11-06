--- Exports environment variables and path adjustments for Mise
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#envkeys-hook
--- @param ctx {path: string, version: string} Context
function PLUGIN:EnvKeys(ctx)
    local target_dir = ctx.path
    local os_type = RUNTIME.osType:lower()
    local is_win = (os_type == "windows")

    local function join_path(a, b)
        local sep = is_win and "\\" or "/"
        local clean_a = a:gsub("[\\/]+$", "")
        local clean_b = b:gsub("^[\\/]+", "")
        return clean_a .. sep .. clean_b
    end

    local bin_dir = join_path(target_dir, "bin")
    local src_dir = join_path(target_dir, "src")

    return {
        -- Add ComfyUI trampolines directly to PATH
        {
            key = "PATH",
            value = bin_dir
        },
        -- Export root for integrations and custom node management
        {
            key = "COMFYUI_HOME",
            value = src_dir
        }
    }
end