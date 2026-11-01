--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()

    if os_type == "windows" then
        -- Windows: Create data folder for portable mode
        os.execute("if not exist \"" .. path .. "\\data\" mkdir \"" .. path .. "\\data\"")
    elseif os_type == "darwin" then
        -- macOS: Create data directory alongside the app bundle for portable storage
        os.execute("mkdir -p \"" .. path .. "/data\"")
        os.execute("chmod -R +x \"" .. path .. "\"")
    else
        -- Linux: tarball extracts into a subfolder named VSCode-linux-x64/
        -- Move everything up to root so paths are deterministic
        local inner_dir = path .. "/VSCode-linux-x64"
        os.execute("if [ -d \"" .. inner_dir .. "\" ]; then cp -rf \"" .. inner_dir .. "/\". \"" .. path .. "/\" && rm -rf \"" .. inner_dir .. "\"; fi")

        -- Create data folder for portable mode
        os.execute("mkdir -p \"" .. path .. "/data\"")
        os.execute("chmod -R +x \"" .. path .. "\"")
    end
end