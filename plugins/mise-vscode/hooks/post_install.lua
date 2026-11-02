--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()
    local stable_file = path .. "/stable"

    -- Decompress the downloaded payload
    local f = io.open(stable_file, "rb")
    if f ~= nil then
        f:close()

        if os_type == "windows" then
            local zip_file = path .. "\\stable.zip"
            -- 1. Rename to .zip so tar.exe recognizes it as a ZIP archive
            os.execute("move /Y \"" .. stable_file .. "\" \"" .. zip_file .. "\" >nul 2>&1")
            -- 2. Fast extract via tar.exe
            os.execute("tar --force-local -xf \"" .. zip_file .. "\" -C \"" .. path .. "\"")
            -- 3. Cleanup zip file
            os.execute("del /Q /F \"" .. zip_file .. "\" >nul 2>&1")
        elseif os_type == "darwin" then
            os.execute("unzip -q -o \"" .. stable_file .. "\" -d \"" .. path .. "\"")
            os.remove(stable_file)
        else
            os.execute("tar -xzf \"" .. stable_file .. "\" -C \"" .. path .. "\"")
            os.remove(stable_file)
        end
    end

    -- Create portable mode data folder
    if os_type == "windows" then
        os.execute("if not exist \"" .. path .. "\\data\" mkdir \"" .. path .. "\\data\"")
    else
        os.execute("mkdir -p \"" .. path .. "/data\"")

        -- On Linux, VS Code tarballs unpack inside VSCode-linux-x64/
        local inner_bin = path .. "/VSCode-linux-x64/bin/code"
        if os.execute("test -f \"" .. inner_bin .. "\"") == 0 then
            os.execute("mkdir -p \"" .. path .. "/bin\"")
            os.execute("ln -sf \"" .. inner_bin .. "\" \"" .. path .. "/bin/code\"")
        end

        os.execute("chmod -R +x \"" .. path .. "\"")
    end
end