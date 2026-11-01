--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path

    -- On Unix-like systems, ensure all extracted binaries and libraries are executable
    if RUNTIME.osType ~= "Windows" then
        os.execute("chmod -R +x \"" .. path .. "\"")
    end
end