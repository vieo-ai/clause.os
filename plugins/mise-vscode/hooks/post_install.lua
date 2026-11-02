--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local archiver = require("archiver")
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()
    local stable_file = path .. "/stable"

    -- Decompress the payload downloaded by Mise
    local f = io.open(stable_file, "r")
    if f ~= nil then
        f:close()
        if os_type == "windows" then
            archiver.unzip(stable_file, path)
        else
            archiver.untar(stable_file, path)
        end
        os.remove(stable_file)
    end

    -- Create portable mode data folder
    if os_type == "windows" then
        os.execute("if not exist \"" .. path .. "\\data\" mkdir \"" .. path .. "\\data\"")
    else
        os.execute("mkdir -p \"" .. path .. "/data\"")
        os.execute("chmod -R +x \"" .. path .. "\"")
    end
end