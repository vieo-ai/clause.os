--- plugins/mise-unsloth/hooks/post_install.lua
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local target_dir = sdkInfo.path

    -- Version is located inside sdkInfo table in Mise's PostInstall context
    local raw_version = (sdkInfo and sdkInfo.version) or ctx.runtimeVersion or ctx.version or "latest"
    local version = tostring(raw_version):gsub("^v", "")

    local os_type = RUNTIME.osType:lower()
    local is_win = (os_type == "windows")
    local is_mac = (os_type == "darwin")

    -- Path configuration matching Section 1
    local venv_dir = is_win and (target_dir .. "\\venv") or (target_dir .. "/venv")
    local private_py_dir = is_win and (target_dir .. "\\python") or (target_dir .. "/python")
    local shim_dir = is_win and (target_dir .. "\\bin") or (target_dir .. "/bin")
    local script_dir = is_win and "Scripts" or "bin"
    local exe_ext = is_win and ".exe" or ""
    local python_bin = venv_dir .. (is_win and "\\" or "/") .. script_dir .. (is_win and "\\python" or "/python") .. exe_ext
    local shim_exe = shim_dir .. (is_win and "\\unsloth.bat" or "/unsloth")

    -- Fast-path idempotency check
    local f_py = io.open(python_bin, "r")
    local f_shim = io.open(shim_exe, "r")
    if f_py and f_shim then
        f_py:close()
        f_shim:close()
        return
    end
    if f_py then f_py:close() end
    if f_shim then f_shim:close() end

    -- Helper to execute shell commands with exit status check
    local function run_cmd(cmd)
        local code = os.execute(cmd)
        if code ~= 0 and code ~= true then
            error(string.format("[ClauseOS] Command failed with exit code %s: %s", tostring(code), cmd))
        end
    end

    -- Helper to capture command output
    local function capture_cmd(cmd)
        local p = io.popen(cmd)
        if not p then return "" end
        local out = p:read("*a")
        p:close()
        return out or ""
    end

    -- Locate uv executable
    local uv_exe = "uv"
    if is_win then
        local check = os.execute("where uv.exe >nul 2>&1")
        if check ~= 0 and check ~= true then
            error("[ClauseOS] Missing required tool: uv. Ensure uv is installed.")
        end
    else
        local check = os.execute("command -v uv >/dev/null 2>&1")
        if check ~= 0 and check ~= true then
            error("[ClauseOS] Missing required tool: uv. Ensure uv is installed.")
        end
    end

    -- Provision directory structure
    if is_win then
        os.execute("if not exist \"" .. target_dir .. "\" mkdir \"" .. target_dir .. "\" >nul 2>&1")
        os.execute("if not exist \"" .. shim_dir .. "\" mkdir \"" .. shim_dir .. "\" >nul 2>&1")
        os.execute("if not exist \"" .. private_py_dir .. "\" mkdir \"" .. private_py_dir .. "\" >nul 2>&1")
    else
        os.execute("mkdir -p \"" .. target_dir .. "\" \"" .. shim_dir .. "\" \"" .. private_py_dir .. "\"")
    end

    -- Hardware Acceleration Detection Matrix (Section 2)
    local pytorch_base_url = "https://download.pytorch.org/whl"
    local torch_index_url = pytorch_base_url .. "/cpu"
    local skip_torch = false

    if is_mac then
        local mac_arch = capture_cmd("uname -m"):gsub("%s+", "")
        if mac_arch == "arm64" then
            torch_index_url = pytorch_base_url .. "/cpu"
        else
            skip_torch = true
        end
    elseif is_win then
        local nvidia_detected = false
        local cuda_major = 0
        local cuda_minor = 0
        local sm_arch = 0

        -- 1. Probe NVIDIA
        local smi_check = os.execute("where nvidia-smi.exe >nul 2>&1")
        if smi_check == 0 or smi_check == true then
            local smi_out = capture_cmd("nvidia-smi.exe 2>nul")
            local maj, min = smi_out:match("CUDA[%s%w]*%s*Version:%s*(%d+)%.(%d+)")
            if maj and min then
                nvidia_detected = true
                cuda_major = tonumber(maj)
                cuda_minor = tonumber(min)

                local sm_out = capture_cmd("nvidia-smi.exe --query-gpu=compute_cap --format=csv,noheader,nounits 2>nul")
                local sm_maj, sm_min = sm_out:match("(%d+)%.(%d+)")
                if sm_maj and sm_min then
                    sm_arch = (tonumber(sm_maj) * 10) + tonumber(sm_min)
                end
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
            elseif cuda_major == 12 then
                cuda_tag = "cu124"
            elseif cuda_major == 11 then
                cuda_tag = "cu118"
            end

            -- Cap pre-Turing (sm < 75) to cu126
            if sm_arch > 0 and sm_arch < 75 and (cuda_tag == "cu128" or cuda_tag == "cu130") then
                cuda_tag = "cu126"
            end
            torch_index_url = pytorch_base_url .. "/" .. cuda_tag
        else
            -- 2. Probe AMD ROCm on Windows via PowerShell CIM
            local ps_cmd = 'powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"'
            local gpu_names = capture_cmd(ps_cmd)
            local rocm_gfx = nil

            if gpu_names:match("9070") or gpu_names:match("9080") or gpu_names:match("R9700") then rocm_gfx = "gfx1201"
            elseif gpu_names:match("9060") then rocm_gfx = "gfx1200"
            elseif gpu_names:match("8065S") or gpu_names:match("8060S") or gpu_names:match("8050S") or gpu_names:match("8040S") or gpu_names:match("Strix Halo") or gpu_names:match("Ryzen AI Max") then rocm_gfx = "gfx1151"
            elseif gpu_names:match("890M") or gpu_names:match("880M") or gpu_names:match("Strix Point") or gpu_names:match("HX 37") then rocm_gfx = "gfx1150"
            elseif gpu_names:match("860M") or gpu_names:match("840M") or gpu_names:match("Krackan") then rocm_gfx = "gfx1152"
            elseif gpu_names:match("RX 7900") or gpu_names:match("PRO W7900") or gpu_names:match("PRO W7800") then rocm_gfx = "gfx1100"
            elseif gpu_names:match("RX 7800") or gpu_names:match("RX 7700") then rocm_gfx = "gfx1101"
            elseif gpu_names:match("RX 7600") or gpu_names:match("RX 7650") or gpu_names:match("PRO W7600") then rocm_gfx = "gfx1102"
            elseif gpu_names:match("780M") or gpu_names:match("760M") or gpu_names:match("Phoenix") or gpu_names:match("Hawk Point") then rocm_gfx = "gfx1103"
            elseif gpu_names:match("RX 6900") or gpu_names:match("RX 6800") or gpu_names:match("RX 6700") then rocm_gfx = "gfx1030"
            elseif gpu_names:match("RX 6600") or gpu_names:match("PRO W6600") then rocm_gfx = "gfx1032"
            end

            if rocm_gfx then
                local multi_arch = {
                    gfx1100 = true, gfx1101 = true, gfx1102 = true, gfx1103 = true,
                    gfx1150 = true, gfx1151 = true, gfx1152 = true, gfx1200 = true, gfx1201 = true
                }
                if multi_arch[rocm_gfx] then
                    torch_index_url = "https://repo.amd.com/rocm/whl-multi-arch/"
                else
                    torch_index_url = "https://repo.amd.com/rocm/whl/" .. rocm_gfx .. "/"
                end
            else
                -- 3. Probe Intel Arc / XPU on Windows
                if gpu_names:match("Intel.*Arc") or gpu_names:match("Data Center GPU") then
                    torch_index_url = pytorch_base_url .. "/xpu"
                else
                    torch_index_url = pytorch_base_url .. "/cpu"
                end
            end
        end
    else
        -- Linux Platform Handling
        local nvidia_detected = false
        local cuda_major = 0
        local cuda_minor = 0
        local sm_arch = 0

        local smi_check = os.execute("command -v nvidia-smi >/dev/null 2>&1")
        if smi_check == 0 or smi_check == true then
            local smi_out = capture_cmd("nvidia-smi 2>/dev/null")
            local maj, min = smi_out:match("CUDA[%s%w]*%s*Version:%s*(%d+)%.(%d+)")
            if maj and min then
                nvidia_detected = true
                cuda_major = tonumber(maj)
                cuda_minor = tonumber(min)

                local sm_out = capture_cmd("nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits 2>/dev/null")
                local sm_maj, sm_min = sm_out:match("(%d+)%.(%d+)")
                if sm_maj and sm_min then
                    sm_arch = (tonumber(sm_maj) * 10) + tonumber(sm_min)
                end
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
            elseif cuda_major == 12 then
                cuda_tag = "cu124"
            elseif cuda_major == 11 then
                cuda_tag = "cu118"
            end

            if sm_arch > 0 and sm_arch < 75 and (cuda_tag == "cu128" or cuda_tag == "cu130") then
                cuda_tag = "cu126"
            end
            torch_index_url = pytorch_base_url .. "/" .. cuda_tag
        else
            -- 2. Probe AMD ROCm on Linux
            local kfd_check = io.open("/dev/kfd", "r")
            local rocminfo_check = (os.execute("command -v rocminfo >/dev/null 2>&1") == 0)

            if kfd_check ~= nil or rocminfo_check then
                if kfd_check then kfd_check:close() end
                local rocm_tag = "rocm6.2"
                if rocminfo_check then
                    local r_out = capture_cmd("rocminfo 2>/dev/null")
                    local r_ver = r_out:match("ROCm Version:%s*(%d+%.%d+)")
                    if r_ver then
                        rocm_tag = "rocm" .. r_ver
                    end
                end
                torch_index_url = pytorch_base_url .. "/" .. rocm_tag
            else
                -- 3. Probe Intel Arc / XPU on Linux
                local dri_check = io.open("/dev/dri", "r")
                local is_intel_arc = false
                if dri_check ~= nil then
                    dri_check:close()
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
                else
                    torch_index_url = pytorch_base_url .. "/cpu"
                end
            end
        end
    end

    -- Section 3: Provision isolated Python 3.12 via uv
    local uv_env = string.format("UV_PYTHON_INSTALL_DIR=\"%s\"", private_py_dir)
    if is_win then
        run_cmd(string.format("set \"UV_PYTHON_INSTALL_DIR=%s\" && %s python install --no-bin --no-registry 3.12", private_py_dir, uv_exe))
    else
        run_cmd(string.format("%s %s python install --no-bin --no-registry 3.12", uv_env, uv_exe))
    end

    local base_python
    if is_win then
        local raw_py = capture_cmd(string.format("set \"UV_PYTHON_INSTALL_DIR=%s\" && %s python find 3.12", private_py_dir, uv_exe))
        base_python = raw_py:match("^[^\r\n]+")
    else
        local raw_py = capture_cmd(string.format("%s %s python find 3.12", uv_env, uv_exe))
        base_python = raw_py:match("^[^\r\n]+")
    end

    if not base_python or base_python == "" then
        error("[ClauseOS] Unable to locate provisioned Python 3.12 in " .. private_py_dir)
    end

    -- Section 4: Assemble virtual environment & runtimes
    run_cmd(string.format("%s venv \"%s\" --python \"%s\"", uv_exe, venv_dir, base_python))

    -- Mark environment ownership
    local mark_path = venv_dir .. (is_win and "\\.unsloth-studio-owned" or "/.unsloth-studio-owned")
    local f_mark = io.open(mark_path, "w")
    if f_mark then
        f_mark:write("")
        f_mark:close()
    end

    -- Section 5: Install PyTorch foundation & core dependencies
    if not skip_torch then
        run_cmd(string.format(
            "%s pip install --python \"%s\" --default-index \"%s\" \"torch>=2.4.0,<2.12.0\" \"torchvision>=0.19.0,<0.27.0\" \"torchaudio>=2.4.0,<2.12.0\"",
            uv_exe, python_bin, torch_index_url
        ))

        if torch_index_url:match("/xpu") then
            run_cmd(string.format("%s pip install --python \"%s\" --no-deps \"bitsandbytes>=0.50.0\"", uv_exe, python_bin))
        end

        local py_query = string.format("\"%s\" -c \"import importlib.metadata as m; print(m.version('torch'))\"", python_bin)
        local installed_torch = capture_cmd(py_query):gsub("%s+", "")
        local override_file = target_dir .. (is_win and "\\torch_override.txt" or "/torch_override.txt")

        local f_over = io.open(override_file, "w")
        if f_over then
            f_over:write(string.format("torch==%s\ntorchvision\ntorchaudio\n", installed_torch))
            f_over:close()
        end

        local install_ok, install_err = pcall(function()
            run_cmd(string.format(
                "%s pip install --python \"%s\" --overrides \"%s\" \"unsloth==%s\" \"unsloth-zoo\"",
                uv_exe, python_bin, override_file, version
            ))
        end)

        os.remove(override_file)

        if not install_ok then
            error(install_err)
        end
    else
        run_cmd(string.format("%s pip install --python \"%s\" --no-deps \"unsloth==%s\" \"unsloth-zoo\"", uv_exe, python_bin, version))
        run_cmd(string.format("%s pip install --python \"%s\" \"pydantic\"", uv_exe, python_bin))
    end

    -- Section 6: Generate CLI trampolines
    local trampoline_py = 'import sys, os; sys.argv[0] = \\"unsloth\\"; from unsloth_cli import app; sys.exit(app())'

    if is_win then
        local cmd_shim = shim_dir .. "\\unsloth.bat"
        local f_shim_win = io.open(cmd_shim, "w")
        if f_shim_win then
            f_shim_win:write("@echo off\r\nsetlocal\r\n")
            f_shim_win:write("\"%~dp0..\\venv\\Scripts\\python.exe\" -X utf8 -c \"" .. trampoline_py .. "\" %*\r\n")
            f_shim_win:write("exit /b %ERRORLEVEL%\r\n")
            f_shim_win:close()
        end
    else
        local sh_shim = shim_dir .. "/unsloth"
        local f_shim_nix = io.open(sh_shim, "w")
        if f_shim_nix then
            f_shim_nix:write("#!/usr/bin/env sh\n")
            f_shim_nix:write("exec \"$(dirname \"$0\")/../venv/bin/python\" -c '" .. trampoline_py:gsub('\\"', '"') .. "' \"$@\"\n")
            f_shim_nix:close()
        end
        os.execute("chmod +x \"" .. sh_shim .. "\"")
    end
end