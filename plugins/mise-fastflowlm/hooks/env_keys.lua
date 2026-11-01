--- Configures environment variables for the installed tool
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#envkeys-hook
--- @param ctx {path: string, runtimeVersion: string, sdkInfo: table} Context
--- @return table[] List of environment variable definitions
function PLUGIN:EnvKeys(ctx)
    local mainPath = ctx.path

    return {
        {
            key = "PATH",
            value = mainPath .. "/bin",
        },
        {
            key = "PATH",
            value = mainPath,
        },
        {
            key = "FASTFLOWLM_HOME",
            value = mainPath,
        },
    }
end