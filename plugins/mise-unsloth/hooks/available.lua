--- Returns available versions for unsloth from PyPI
--- @param ctx {args: string[]} Context
--- @return table[] List of available versions
function PLUGIN:Available(ctx)
    local http = require("http")
    local json = require("json")

    local resp, err = http.get({
        url = "https://pypi.org/pypi/unsloth/json",
    })

    if err ~= nil or resp.status_code ~= 200 then
        error("Failed to query PyPI releases for unsloth")
    end

    local data = json.decode(resp.body)
    local releases = data.releases or {}
    local result = {}

    for ver, _ in pairs(releases) do
        -- Only accept standard release tags (ignore alpha/rc if preferred, or include all)
        if ver:match("^%d+%.%d+") then
            table.insert(result, {
                version = ver,
            })
        end
    end

    return result
end