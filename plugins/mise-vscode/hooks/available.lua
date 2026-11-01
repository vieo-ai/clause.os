--- Returns a list of available versions for the tool
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#available-hook
--- @param ctx {args: string[]} Context (args = user arguments)
--- @return table[] List of available versions
function PLUGIN:Available(ctx)
    local http = require("http")
    local json = require("json")

    -- Query official Microsoft VS Code update API for available stable releases
    local update_url = "https://update.code.visualstudio.com/api/releases/stable"

    local resp, err = http.get({
        url = update_url,
    })

    if err ~= nil then
        error("Failed to fetch VS Code versions: " .. err)
    end
    if resp.status_code ~= 200 then
        error("VS Code update API returned status " .. resp.status_code .. ": " .. resp.body)
    end

    local versions = json.decode(resp.body)
    local result = {}

    for _, ver in ipairs(versions) do
        local clean_version = ver:gsub("^v", "")
        if clean_version ~= "" then
            table.insert(result, {
                version = clean_version,
                note = nil,
            })
        end
    end

    return result
end