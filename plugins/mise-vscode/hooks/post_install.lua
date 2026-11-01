--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    -- local version = sdkInfo.version

    -- Faithful translation of installer_vscode.ps1:
    -- New-Item -ItemType Directory -Path (Join-Path $CodeDir "data") -Force | Out-Null
    -- Creates the data/ directory to put VS Code into Portable Mode
    if RUNTIME.osType == "Windows" then
        os.execute("if not exist \"" .. path .. "\\data\" mkdir \"" .. path .. "\\data\"")
    else
        os.execute("mkdir -p \"" .. path .. "/data\"")

        -- Ensure all binaries and scripts are executable across the archive
        os.execute("chmod -R +x \"" .. path .. "\"")
    end
end