--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path

    -- Ensure standard bin directory exists
    os.execute("mkdir -p " .. path .. "/bin")

    if RUNTIME.osType == "Windows" then
        -- Find fastflowlm executable (or nested binary) and normalize into bin/
        os.execute("find \"" .. path .. "\" -type f -name \"fastflow*.exe\" -not -path \"" .. path .. "/bin/*\" -exec cp -f {} \"" .. path .. "/bin/fastflowlm.exe\" \\; 2>/dev/null || true")
    else
        -- Find executable binary across potential subdirectories and normalize to bin/fastflowlm
        os.execute("find \"" .. path .. "\" -maxdepth 3 -type f \\( -name \"fastflow*\" -o -name \"fastflowlm\" \\) -not -path \"" .. path .. "/bin/*\" -exec cp -f {} \"" .. path .. "/bin/fastflowlm\" \\; 2>/dev/null || true")
        -- Ensure all binaries inside bin are executable
        os.execute("chmod -R +x " .. path .. "/bin")
    end
end