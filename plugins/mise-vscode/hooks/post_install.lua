--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()

    if os_type == "windows" then
        os.execute("if not exist \"" .. path .. "\\data\" mkdir \"" .. path .. "\\data\"")
    elseif os_type == "darwin" then
        os.execute("mkdir -p \"" .. path .. "/data\"")
        os.execute("mkdir -p \"" .. path .. "/bin\"")
        local mac_bin = path .. "/Visual Studio Code.app/Contents/Resources/app/bin/code"
        os.execute("ln -sf \"" .. mac_bin .. "\" \"" .. path .. "/bin/code\"")
        os.execute("chmod -R +x \"" .. path .. "\"")
    else
        local inner_dir = path .. "/VSCode-linux-x64"
        os.execute("if [ -d \"" .. inner_dir .. "\" ]; then cp -rf \"" .. inner_dir .. "/\". \"" .. path .. "/\" && rm -rf \"" .. inner_dir .. "\"; fi")
        os.execute("mkdir -p \"" .. path .. "/data\"")
        os.execute("chmod -R +x \"" .. path .. "\"")
        os.execute("chmod +x \"" .. path .. "/bin/code\" 2>/dev/null || true")
    end
end