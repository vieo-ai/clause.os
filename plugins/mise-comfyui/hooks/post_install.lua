--- Performs hermetic setup and hardware-aware installation after Mise provisions the root path
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local target_dir = sdkInfo.path

    local raw_version = (sdkInfo and sdkInfo.version) or ctx.runtimeVersion or ctx.version or "latest"
    local version = tostring(raw_version):gsub("^v", "")

    local os_type = RUNTIME.osType:lower()
    local is_win = (os_type == "windows")
    local is_mac = (os_type == "darwin")

    local function join_path(a, b)
        if not a or a == "" then return b end
        if not b or b == "" then return a end
        local sep = is_win and "\\" or "/"
        local clean_a = a:gsub("[\\/]+$", "")
        local clean_b = b:gsub("^[\\/]+", "")
        return clean_a .. sep .. clean_b
    end

    local function test_path(p)
        if not p or p == "" then return false end
        local f = io.open(p, "r")
        if f ~= nil then
            f:close()
            return true
        end
        return false
    end

    -- Idiomatic Mise logging via stderr
    local function log(msg, level)
        io.stderr:write(string.format("[comfyui][%s] %s\n", level or "INFO", msg))
    end

    local function run_cmd(cmd)
        local code = os.execute(cmd)
        if code ~= 0 and code ~= true then
            error(string.format("[comfyui] Command failed with exit code %s: %s", tostring(code), cmd))
        end
    end

    local function capture_cmd(cmd)
        local full_cmd = cmd
        if is_win then
            full_cmd = '%COMSPEC% /d /s /c "' .. cmd .. '"'
        end
        local p = io.popen(full_cmd)
        if not p then return "" end
        local out = p:read("*a")
        p:close()
        return out or ""
    end

    -- ==============================================================================
    -- 1. HERMETIC ROOTS & DIRECTORY MAPPING
    -- ==============================================================================
    local venv_dir = join_path(target_dir, "venv")
    local source_dir = join_path(target_dir, "src")
    local private_py_dir = join_path(target_dir, "python")
    local shim_dir = join_path(target_dir, "bin")
    local script_dir = is_win and "Scripts" or "bin"
    local exe_ext = is_win and ".exe" or ""
    local python_bin = join_path(venv_dir, script_dir .. (is_win and "\\python" or "/python") .. exe_ext)
    local main_py = join_path(source_dir, "main.py")
    local shim_bat = join_path(shim_dir, "comfyui.bat")
    local shim_sh = join_path(shim_dir, "comfyui")

    -- Fast-path idempotency check
    if test_path(python_bin) and test_path(main_py) and (test_path(shim_bat) or test_path(shim_sh)) then
        return
    end

    -- Resolve uv executable
    local uv_exe = nil
    local clause_bin = os.getenv("CLAUSE_BIN_DIR") or ""
    local clause_home = os.getenv("CLAUSE_HOME") or ""
    local direct_uv = clause_bin ~= "" and join_path(clause_bin, "uv" .. exe_ext) or ""

    if direct_uv ~= "" and test_path(direct_uv) then
        uv_exe = direct_uv
    else
        local cmd_probe = is_win and capture_cmd("where uv.exe 2>nul") or capture_cmd("command -v uv 2>/dev/null")
        local found_uv = cmd_probe:match("^[^\r\n]+")
        if found_uv and found_uv ~= "" and test_path(found_uv) then
            uv_exe = found_uv
        else
            local mise_shim_rel = is_win and "AppData\\Local\\mise\\shims\\uv.exe" or ".local/share/mise/shims/uv"
            local mise_shims = clause_home ~= "" and join_path(clause_home, mise_shim_rel) or ""
            if mise_shims ~= "" and test_path(mise_shims) then
                uv_exe = mise_shims
            else
                local user_home = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
                local alt_shims = join_path(user_home, mise_shim_rel)
                if test_path(alt_shims) then
                    uv_exe = alt_shims
                else
                    local mise_uv_base = is_win and join_path(user_home, "AppData\\Local\\mise\\installs\\uv")
                                               or join_path(user_home, ".local/share/mise/installs/uv")
                    local p_find = capture_cmd(is_win and ('dir /b /s "' .. mise_uv_base .. '\\uv.exe" 2>nul')
                                                      or ('find "' .. mise_uv_base .. '" -type f -name uv 2>/dev/null'))
                    local first_found = p_find:match("^[^\r\n]+")
                    if first_found and first_found ~= "" and test_path(first_found) then
                        uv_exe = first_found
                    else
                        log("uv is not available in PATH. Ensure 'mise install uv' has completed.", "FATAL")
                        error("[comfyui] Missing required tool: uv")
                    end
                end
            end
        end
    end

    if not uv_exe then
        log("uv package manager missing. Ensure 'uv' is seeded via Mise.", "FATAL")
        error("[comfyui] Missing prerequisite: uv")
    end

    log("Initializing Hermetic ComfyUI Studio Deployment (" .. version .. ")...", "INFO")

    local clause_temp_dir = os.getenv("CLAUSE_TEMP_DIR") or (is_win and (os.getenv("TEMP") or target_dir) or "/tmp")
    local clause_cache_dir = os.getenv("CLAUSE_CACHE_DIR") or join_path(target_dir, "cache")
    local uv_cache_dir = join_path(clause_cache_dir, "uv")
    local uv_python_install_dir = private_py_dir

    -- Provision directory tree
    local dirs_to_provision = { target_dir, shim_dir, private_py_dir, source_dir, clause_temp_dir, clause_cache_dir, uv_cache_dir }
    for _, d in ipairs(dirs_to_provision) do
        if not test_path(d) then
            if is_win then
                os.execute("if not exist \"" .. d .. "\" mkdir \"" .. d .. "\" >nul 2>&1")
            else
                os.execute("mkdir -p \"" .. d .. "\"")
            end
        end
    end

    local function run_uv(subcommand)
        if is_win then
            run_cmd(string.format("set \"UV_CACHE_DIR=%s\" && set \"UV_PYTHON_INSTALL_DIR=%s\" && \"%s\" %s", uv_cache_dir, uv_python_install_dir, uv_exe, subcommand))
        else
            run_cmd(string.format("UV_CACHE_DIR=\"%s\" UV_PYTHON_INSTALL_DIR=\"%s\" \"%s\" %s", uv_cache_dir, uv_python_install_dir, uv_exe, subcommand))
        end
    end

    local function capture_uv(subcommand)
        if is_win then
            return capture_cmd(string.format("set \"UV_CACHE_DIR=%s\" && set \"UV_PYTHON_INSTALL_DIR=%s\" && \"%s\" %s", uv_cache_dir, uv_python_install_dir, uv_exe, subcommand))
        else
            return capture_cmd(string.format("UV_CACHE_DIR=\"%s\" UV_PYTHON_INSTALL_DIR=\"%s\" \"%s\" %s", uv_cache_dir, uv_python_install_dir, uv_exe, subcommand))
        end
    end

    -- ==============================================================================
    -- 2. STAGE COMFYUI REPOSITORY
    -- ==============================================================================
    if not test_path(main_py) then
        log("Cloning ComfyUI source (" .. version .. ")...", "INFO")
        local git_available = (is_win and os.execute("where git.exe >nul 2>&1") == 0) or (not is_win and os.execute("command -v git >/dev/null 2>&1") == 0)

        if git_available then
            local branch_arg = (version ~= "latest" and version ~= "") and ("--branch " .. version) or ""
            local clone_cmd = string.format("git clone --depth 1 %s https://github.com/Comfy-Org/ComfyUI.git \"%s\"", branch_arg, source_dir)
            local clone_ok = pcall(run_cmd, clone_cmd)
            if not clone_ok then
                -- Fallback if specific tag wasn't found as branch
                run_cmd(string.format("git clone --depth 1 https://github.com/Comfy-Org/ComfyUI.git \"%s\"", source_dir))
            end
        else
            local archive_url = (version ~= "latest" and version ~= "") 
                and string.format("https://github.com/Comfy-Org/ComfyUI/archive/refs/tags/%s.zip", version)
                or "https://github.com/Comfy-Org/ComfyUI/archive/refs/heads/master.zip"
            
            local zip_path = join_path(clause_temp_dir, "comfyui.zip")
            local extract_target = join_path(clause_temp_dir, "comfy_extract")

            if is_win then
                run_cmd(string.format("powershell -NoProfile -Command \"Invoke-WebRequest -Uri '%s' -OutFile '%s'\"", archive_url, zip_path))
                run_cmd(string.format("powershell -NoProfile -Command \"Expand-Archive -LiteralPath '%s' -DestinationPath '%s' -Force\"", zip_path, extract_target))
                -- Move extracted nested directory to source_dir
                run_cmd(string.format("powershell -NoProfile -Command \"Get-ChildItem -Path '%s' -Directory | Select-Object -First 1 | ForEach-Object { Copy-Item -Path ($_.FullName + '\\*') -Destination '%s' -Recurse -Force }\"", extract_target, source_dir))
            else
                run_cmd(string.format("curl -sSL \"%s\" -o \"%s\"", archive_url, zip_path))
                run_cmd(string.format("unzip -q -o \"%s\" -d \"%s\"", zip_path, extract_target))
                run_cmd(string.format("cp -rf \"%s\"/*/* \"%s\"/", extract_target, source_dir))
            end

            if test_path(zip_path) then os.remove(zip_path) end
        end
    end

    -- ==============================================================================
    -- 3. PROVISION ISOLATED PYTHON 3.12 VIA UV
    -- ==============================================================================
    log("Provisioning standalone hermetic Python 3.12 into " .. private_py_dir .. "...", "DEBUG")
    run_uv("python install --no-bin --no-registry 3.12")

    local base_python_out = capture_uv("python find 3.12")
    local base_python = ""

    for line in base_python_out:gmatch("[^\r\n]+") do
        local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" and test_path(trimmed) then
            base_python = trimmed
            break
        end
    end

    if base_python == "" or not test_path(base_python) then
        if is_win then
            local p_scan = capture_cmd(string.format('dir /b /s "%s\\python.exe" 2>nul', private_py_dir))
            for line in p_scan:gmatch("[^\r\n]+") do
                local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed ~= "" and test_path(trimmed) then
                    base_python = trimmed
                    break
                end
            end
        else
            local p_scan = capture_cmd(string.format('find "%s" -type f -name "python3.12" 2>/dev/null', private_py_dir))
            for line in p_scan:gmatch("[^\r\n]+") do
                local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed ~= "" and test_path(trimmed) then
                    base_python = trimmed
                    break
                end
            end
        end
    end

    if base_python == "" or not test_path(base_python) then
        error("Unable to locate provisioned Python 3.12 in " .. private_py_dir)
    end

    if not test_path(python_bin) then
        log("Creating ComfyUI virtual environment at " .. venv_dir .. "...", "DEBUG")
        run_uv(string.format("venv \"%s\" --python \"%s\"", venv_dir, base_python))
    end

    local ownership_marker = join_path(venv_dir, ".comfyui-owned")
    local f_mark = io.open(ownership_marker, "w")
    if f_mark then
        f_mark:write("")
        f_mark:close()
    end

    -- ==============================================================================
    -- 4. HARDWARE-AWARE PYTORCH FOUNDATION SELECTION
    -- ==============================================================================
    local pytorch_base_url = "https://download.pytorch.org/whl"
    local torch_index_url = pytorch_base_url .. "/cpu"
    local torch_packages = "\"torch\" \"torchvision\" \"torchaudio\""

    if is_mac then
        log("Targeting Apple Silicon / macOS CPU-MPS runtime.", "INFO")
        torch_index_url = pytorch_base_url .. "/cpu"
    elseif is_win then
        -- ── Windows Hardware Probing ──
        local nvidia_detected = false
        local cuda_major = 0
        local cuda_minor = 0

        local smi_check = os.execute("where nvidia-smi.exe >nul 2>&1")
        if smi_check == 0 or smi_check == true then
            local smi_out = capture_cmd("nvidia-smi.exe 2>nul")
            local maj, min = smi_out:match("CUDA[%s%w]*%s*Version:%s*(%d+)%.(%d+)")
            if maj and min then
                nvidia_detected = true
                cuda_major = tonumber(maj)
                cuda_minor = tonumber(min)
            end
        end

        if nvidia_detected then
            local cuda_tag = "cu124"
            if cuda_major >= 13 then
                cuda_tag = "cu130"
            elseif cuda_major == 12 and cuda_minor >= 8 then
                cuda_tag = "cu128"
            elseif cuda_major == 12 and cuda_minor >= 6 then
                cuda_tag = "cu126"
            else
                cuda_tag = "cu124"
            end

            torch_index_url = pytorch_base_url .. "/" .. cuda_tag
            log("Detected NVIDIA GPU (CUDA " .. tostring(cuda_major) .. "." .. tostring(cuda_minor) .. ") -> Target Index: " .. torch_index_url, "INFO")
        else
            -- Check AMD on Windows via WMI / PowerShell Base64
            local gpu_names = capture_cmd("wmic path win32_videocontroller get name 2>nul")
            if not gpu_names:find("Name") then
                gpu_names = capture_cmd("powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand RwBlAHQALQBDAGkAbQBJAG4AcwB0AGEAbgBjAGUAIABXAGkAbgAzADIAXwBWAGkAZABlAG8AQwBvAG4AdAByAG8AbABsAGUAcgAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBFAHgAcABhAG4AZABQAHIAbwBwAGUAcgB0AHkAIABOAGEAbQBlAA== 2>nul")
            end

            local amd_detected = false
            for line in gpu_names:gmatch("[^\r\n]+") do
                if line:find("AMD") or line:find("Radeon") then
                    amd_detected = true
                    break
                end
            end

            if amd_detected then
                torch_index_url = "https://stable.repo.amd.com/rocm/whl-next/"
                torch_packages = "\"torch[device-all]==2.13.0+rocm10.0.0\" \"torchvision[device-all]==0.28.0+rocm10.0.0\" \"torchaudio==2.11.0.2+rocm10.0.0\""
                log("Detected AMD GPU on Windows -> Target Index: AMD ROCm 10.0 Multi-Arch", "INFO")
            else
                -- Check Intel Arc / XPU
                local intel_detected = false
                for line in gpu_names:gmatch("[^\r\n]+") do
                    if line:match("Intel.*Arc") or line:match("Data Center GPU") then
                        intel_detected = true
                        break
                    end
                end

                if intel_detected then
                    torch_index_url = pytorch_base_url .. "/xpu"
                    log("Detected Intel Arc / XPU device -> Target Index: " .. torch_index_url, "INFO")
                else
                    log("No GPU acceleration detected. Defaulting to CPU PyTorch.", "WARN")
                end
            end
        end
    else
        -- ── Linux Hardware Probing ──
        local nvidia_detected = false
        local cuda_major = 0
        local cuda_minor = 0

        local smi_check = os.execute("command -v nvidia-smi >/dev/null 2>&1")
        if smi_check == 0 or smi_check == true then
            local smi_out = capture_cmd("nvidia-smi 2>/dev/null")
            local maj, min = smi_out:match("CUDA[%s%w]*%s*Version:%s*(%d+)%.(%d+)")
            if maj and min then
                nvidia_detected = true
                cuda_major = tonumber(maj)
                cuda_minor = tonumber(min)
            end
        end

        if nvidia_detected then
            local cuda_tag = "cu124"
            if cuda_major >= 13 then
                cuda_tag = "cu130"
            elseif cuda_major == 12 and cuda_minor >= 8 then
                cuda_tag = "cu128"
            elseif cuda_major == 12 and cuda_minor >= 6 then
                cuda_tag = "cu126"
            else
                cuda_tag = "cu124"
            end

            torch_index_url = pytorch_base_url .. "/" .. cuda_tag
            log("Detected NVIDIA GPU (CUDA " .. tostring(cuda_major) .. "." .. tostring(cuda_minor) .. ") -> Target Index: " .. torch_index_url, "INFO")
        elseif test_path("/dev/kfd") or (os.execute("command -v rocminfo >/dev/null 2>&1") == 0) then
            torch_index_url = pytorch_base_url .. "/rocm7.2"
            log("Detected AMD ROCm Acceleration -> Target Index: " .. torch_index_url, "INFO")
        elseif test_path("/dev/dri") then
            local is_intel_arc = false
            if os.execute("command -v lspci >/dev/null 2>&1") == 0 then
                local lspci_out = capture_cmd("lspci -nn 2>/dev/null")
                if lspci_out:match("VGA compatible controller.*Intel.*Arc") or
                   lspci_out:match("Data Center GPU") or
                   lspci_out:match("7d55") or
                   lspci_out:match("5690") or
                   lspci_out:match("56a0") then
                    is_intel_arc = true
                end
            end

            if is_intel_arc then
                torch_index_url = pytorch_base_url .. "/xpu"
                log("Detected Intel Arc / XPU device -> Target Index: " .. torch_index_url, "INFO")
            else
                log("No GPU acceleration detected. Defaulting to CPU PyTorch.", "WARN")
            end
        else
            log("No GPU acceleration detected. Defaulting to CPU PyTorch.", "WARN")
        end
    end

    -- ==============================================================================
    -- 5. INSTALL DEPENDENCIES
    -- ==============================================================================
    log("Installing PyTorch dependencies (" .. torch_index_url .. ")...", "INFO")
    run_uv(string.format(
        "pip install --python \"%s\" --default-index \"%s\" %s",
        python_bin, torch_index_url, torch_packages
    ))

    -- Install ComfyUI requirements.txt
    local req_file = join_path(source_dir, "requirements.txt")
    if test_path(req_file) then
        log("Installing ComfyUI requirements...", "INFO")

        local is_mac_intel = false
        if is_mac then
            local mac_arch = capture_cmd("uname -m 2>/dev/null"):gsub("[\r\n]+", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if mac_arch == "x86_64" then
                is_mac_intel = true
            end
        end

        if is_mac_intel then
            log("Intel Mac (x86_64) detected: Filtering non-x86_64 wheels (e.g. comfy-angle)...", "WARN")
            local filtered_req = join_path(clause_temp_dir, "comfy_req_mac_intel_" .. tostring(os.time()) .. ".txt")
            
            local f_in = io.open(req_file, "r")
            local f_out = io.open(filtered_req, "w")
            if f_in and f_out then
                for line in f_in:lines() do
                    if not line:match("^%s*comfy%-angle") then
                        f_out:write(line .. "\n")
                    end
                end
                f_in:close()
                f_out:close()
            end

            local req_ok, req_err = pcall(function()
                run_uv(string.format("pip install --python \"%s\" -r \"%s\"", python_bin, filtered_req))
            end)

            if test_path(filtered_req) then os.remove(filtered_req) end
            if not req_ok then error(req_err) end
        else
            run_uv(string.format("pip install --python \"%s\" -r \"%s\"", python_bin, req_file))
        end
    end

    -- ==============================================================================
    -- 6. GENERATE APPLICATION SHIMS
    -- ==============================================================================
    if is_win then
        local cmd_shim = join_path(shim_dir, "comfyui.bat")
        local f_cmd = io.open(cmd_shim, "w")
        if f_cmd then
            f_cmd:write("@echo off\r\nsetlocal\r\n")
            f_cmd:write("\"%~dp0..\\venv\\Scripts\\python.exe\" \"%~dp0..\\src\\main.py\" %*\r\n")
            f_cmd:write("exit /b %ERRORLEVEL%\r\n")
            f_cmd:close()
        end
    else
        local sh_shim = join_path(shim_dir, "comfyui")
        local f_sh = io.open(sh_shim, "w")
        if f_sh then
            f_sh:write("#!/usr/bin/env sh\n")
            f_sh:write("exec \"$(dirname \"$0\")/../venv/bin/python\" \"$(dirname \"$0\")/../src/main.py\" \"$@\"\n")
            f_sh:close()
        end
        os.execute("chmod +x \"" .. sh_shim .. "\"")
    end

    log("ComfyUI Studio engine successfully provisioned.", "INFO")
end