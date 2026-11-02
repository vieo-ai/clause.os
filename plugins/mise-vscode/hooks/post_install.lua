--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()

    if os_type == "windows" then
        local stable_file = path .. "\\stable"
        local f = io.open(stable_file, "rb")
        if f ~= nil then
            f:close()
            local cmd = string.format(
                'powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory(\'%s\', \'%s\'); Remove-Item -Force \'%s\'"',
                stable_file,
                path,
                stable_file
            )
            os.execute(cmd)
        end

        os.execute("if not exist \"" .. path .. "\\data\" mkdir \"" .. path .. "\\data\"")
    elseif os_type == "darwin" then
        local stable_file = path .. "/stable"
        local f = io.open(stable_file, "rb")
        if f ~= nil then
            f:close()
            os.execute("unzip -q -o \"" .. stable_file .. "\" -d \"" .. path .. "\"")
            os.remove(stable_file)
        end
        os.execute("mkdir -p \"" .. path .. "/data\"")
        os.execute("chmod -R +x \"" .. path .. "\"")
    else
        -- Linux
        local stable_file = path .. "/stable"
        local f = io.open(stable_file, "rb")
        if f ~= nil then
            f:close()
            -- --strip-components=1 dumps contents directly into path without the VSCode-linux-x64 folder
            os.execute("tar -xzf \"" .. stable_file .. "\" --strip-components=1 -C \"" .. path .. "\"")
            os.remove(stable_file)
        end

        -- Create portable data directory
        os.execute("mkdir -p \"" .. path .. "/data\"")
        os.execute("chmod -R +x \"" .. path .. "\"")
    end
end