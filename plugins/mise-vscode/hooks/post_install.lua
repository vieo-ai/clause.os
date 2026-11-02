--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()

    if os_type == "windows" then
        -- Native Windows portable mode marker
        os.execute("if not exist \"" .. path .. "\\data\" mkdir \"" .. path .. "\\data\"")
    elseif os_type == "darwin" then
        -- macOS portable data dir and CLI symlink
        os.execute("mkdir -p \"" .. path .. "/data\"")
        os.execute("mkdir -p \"" .. path .. "/bin\"")
        local mac_bin = path .. "/Visual Studio Code.app/Contents/Resources/app/bin/code"
        if os.execute("test -f \"" .. mac_bin .. "\"") == 0 then
            os.execute("ln -sf \"" .. mac_bin .. "\" \"" .. path .. "/bin/code\"")
        end
        os.execute("chmod -R +x \"" .. path .. "\"")
    else
        -- Linux portable data dir and permissions
        os.execute("mkdir -p \"" .. path .. "/data\"")

        -- If Linux tarball extracted into a subfolder, bring bin/ up or link it
        local inner_bin = path .. "/VSCode-linux-x64/bin/code"
        if os.execute("test -f \"" .. inner_bin .. "\"") == 0 then
            os.execute("mkdir -p \"" .. path .. "/bin\"")
            os.execute("ln -sf \"" .. inner_bin .. "\" \"" .. path .. "/bin/code\"")
        end

        os.execute("chmod -R +x \"" .. path .. "\"")
    end
end