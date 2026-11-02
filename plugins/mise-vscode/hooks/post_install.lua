--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()

    if os_type == "windows" then
        local stable_file = path .. "\\stable"
        local zip_file = path .. "\\stable.zip"

        local f = io.open(stable_file, "rb")
        if f ~= nil then
            f:close()
            os.remove(zip_file)
            os.rename(stable_file, zip_file)

            -- cd directly into the install dir so tar doesn't choke on "C:"
            os.execute("cd /d \"" .. path .. "\" && tar --force-local -xf stable.zip && del /Q /F stable.zip >nul 2>&1")
        end

        -- Create portable data directory
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
            os.execute("tar -xzf \"" .. stable_file .. "\" -C \"" .. path .. "\"")
            os.remove(stable_file)
        end

        os.execute("mkdir -p \"" .. path .. "/data\"")

        local inner_bin = path .. "/VSCode-linux-x64/bin/code"
        if os.execute("test -f \"" .. inner_bin .. "\"") == 0 then
            os.execute("mkdir -p \"" .. path .. "/bin\"")
            os.execute("ln -sf \"" .. inner_bin .. "\" \"" .. path .. "/bin/code\"")
        end

        os.execute("chmod -R +x \"" .. path .. "\"")
    end
end