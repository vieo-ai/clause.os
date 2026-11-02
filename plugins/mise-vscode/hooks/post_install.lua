--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local archiver = require("archiver")
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()
    local stable_file = path .. "/stable"

    -- Check if the downloaded payload exists as 'stable'
    local f = io.open(stable_file, "rb")
    if f ~= nil then
        f:close()
        
        -- Native decompression call in Mise/vfox Lua runtime
        local success, err = pcall(function()
            archiver.decompress({
                src = stable_file,
                to = path,
            })
        end)

        -- If Lua archiver fails on extensionless file, use OS native extract tools
        if not success then
            if os_type == "windows" then
                os.execute("powershell -Command \"Expand-Archive -Force -Path '" .. stable_file .. "' -DestinationPath '" .. path .. "'\"")
            elseif os_type == "darwin" then
                os.execute("unzip -q -o \"" .. stable_file .. "\" -d \"" .. path .. "\"")
            else
                os.execute("tar -xzf \"" .. stable_file .. "\" -C \"" .. path .. "\"")
            end
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