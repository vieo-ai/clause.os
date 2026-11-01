-- metadata.lua
-- Plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/tool-plugin-development.html#metadata-lua

PLUGIN = { -- luacheck: ignore
    -- Required: Plugin metadata name
    name = "lemonade",

    -- Required: Plugin metadata version
    version = "1.0.0",

    -- Optional: Plugin description
    description = "ClauseOS Lemonade GPU Engine",

    -- Optional: Plugin author
    author = "vieo-ai",

    -- Optional: License name
    license = "Apache-2.0",

    -- Optional: Plugin homepage
    homepage = "https://github.com/vieo-ai/mise-lemonade",

    -- Optional: Legacy version files this plugin can parse
    -- legacyFilenames = {
    --     ".<TOOL>-version",
    --     ".<TOOL>rc"
    -- },

    -- Optional: configured mise tools to add to install-hook PATH
    -- depends = { "node" },
}
