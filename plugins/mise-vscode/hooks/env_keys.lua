--- Configures environment variables for the installed tool
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#envkeys-hook
--- @param ctx {path: string, runtimeVersion: string, sdkInfo: table} Context
--- @return table[] List of environment variable definitions
function PLUGIN:EnvKeys(ctx)
    local mainPath = ctx.path
    -- local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    -- local version = sdkInfo.version

    local env_vars = {
        {
            key = "VSCODE_HOME",
            value = mainPath,
        },
        {
            key = "PATH",
            value = mainPath .. "/bin",
        },
        {
            key = "PATH",
            value = mainPath,
        },
    }

    -- macOS app bundle command-line tools path:
    -- Visual Studio Code.app/Contents/Resources/app/bin
    if RUNTIME.osType == "Darwin" then
        table.insert(env_vars, {
            key = "PATH",
            value = mainPath .. "/Visual Studio Code.app/Contents/Resources/app/bin",
        })
    end

    return env_vars
end