-- metadata.lua
-- Plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/tool-plugin-development.html#metadata-lua

PLUGIN = { -- luacheck: ignore
    -- Required: Plugin metadata name
    name = "comfyui",

    -- Required: Plugin metadata version
    version = "1.0.0",

    -- Optional: Plugin description
    description = "A mise tool plugin for ComfyUI",

    -- Optional: Plugin author
    author = "vieo-ai",

    -- Optional: License name
    license = "MIT",

    -- Optional: Plugin homepage
    homepage = "https://github.com/vieo-ai/mise-comfyui",

    -- Optional: Legacy version files this plugin can parse
    -- legacyFilenames = {
    --     ".comfyui-version",
    --     ".comfyuirc"
    -- },

    -- Optional: configured mise tools to add to install-hook PATH
    depends = { "uv" },
}
