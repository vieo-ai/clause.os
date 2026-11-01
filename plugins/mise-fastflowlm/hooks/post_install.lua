--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path

    -- Ensure a dedicated bin directory exists
    os.execute("mkdir -p \"" .. path .. "/bin\"")

    if RUNTIME.osType == "Windows" then
        -- The archive contains flm.exe directly in root
        local srcExe = path .. "/flm.exe"
        local destExe = path .. "/bin/flm.exe"
        local aliasExe = path .. "/bin/fastflowlm.exe"

        -- Copy flm.exe to bin/ and create fastflowlm.exe alias
        if os.execute("dir \"" .. srcExe .. "\" >nul 2>&1") == 0 or os.execute("test -f \"" .. srcExe .. "\"") == 0 then
            os.execute("cp -f \"" .. srcExe .. "\" \"" .. destExe .. "\"")
            os.execute("cp -f \"" .. srcExe .. "\" \"" .. aliasExe .. "\"")
        end
    else
        -- Linux flat archive: flm binary in root
        local srcBin = path .. "/flm"
        local destBin = path .. "/bin/flm"
        local aliasBin = path .. "/bin/fastflowlm"

        -- Ensure files in root are executable
        os.execute("chmod -R +x \"" .. path .. "\"")

        -- Move/link flm to bin/flm and alias to fastflowlm
        if os.execute("test -f \"" .. srcBin .. "\"") == 0 then
            os.execute("cp -f \"" .. srcBin .. "\" \"" .. destBin .. "\"")
            os.execute("cp -f \"" .. srcBin .. "\" \"" .. aliasBin .. "\"")
        end

        os.execute("chmod -R +x \"" .. path .. "/bin\"")
    end
end