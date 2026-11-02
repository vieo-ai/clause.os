--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local path = sdkInfo.path
    local os_type = RUNTIME.osType:lower()

    -- Normalize path with forward slashes for clean tool execution across all OSes
    local norm_path = path:gsub("\\", "/")
    local stable_file = norm_path .. "/stable"

    -- Decompress the downloaded payload
    local f = io.open(stable_file, "rb")
    if f ~= nil then
        f:close()

        if os_type == "windows" then
            local zip_file = norm_path .. "/stable.zip"
            -- 1. Native Lua file rename (no cmd.exe dependency)
            os.remove(zip_file)
            os.rename(stable_file, zip_file)

            -- 2. Extract using forward slashes so Windows tar handles paths cleanly
            os.execute("tar -xf \"" .. zip_file .. "\" -C \"" .. norm_path .. "\"")

            -- 3. Cleanup zip file
            os.remove(zip_file)
        elseif os_type == "darwin" then
            os.execute("unzip -q -o \"" .. stable_file .. "\" -d \"" .. norm_path .. "\"")
            os.remove(stable_file)
        else
            os.execute("tar -xzf \"" .. stable_file .. "\" -C \"" .. norm_path .. "\"")
            os.remove(stable_file)
        end
    end

    -- Create portable mode data folder
    if os_type == "windows" then
        os.execute("if not exist \"" .. path .. "\\data\" mkdir \"" .. path .. "\\data\"")
    else
        os.execute("mkdir -p \"" .. norm_path .. "/data\"")

        -- On Linux, VS Code tarballs unpack inside VSCode-linux-x64/
        local inner_bin = norm_path .. "/VSCode-linux-x64/bin/code"
        if os.execute("test -f \"" .. inner_bin .. "\"") == 0 then
            os.execute("mkdir -p \"" .. norm_path .. "/bin\"")
            os.execute("ln -sf \"" .. inner_bin .. "\" \"" .. norm_path .. "/bin/code\"")
        end

        os.execute("chmod -R +x \"" .. norm_path .. "\"")
    end
end