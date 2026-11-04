--- Performs additional setup after installation
--- Documentation: https://mise.jdx.dev/tool-plugin-development.html#postinstall-hook
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo[PLUGIN.name]
    local target_dir = sdkInfo.path

    -- Version is located inside sdkInfo table in Mise's PostInstall context
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
        io.stderr:write(string.format("[unsloth][%s] %s\n", level or "INFO", msg))
    end

    -- ==============================================================================
    -- 1. RESOLVE PATHS & ENFORCE HERMETIC SANDBOX
    -- ==============================================================================
    local venv_dir = join_path(target_dir, "venv")
    local private_py_dir = join_path(target_dir, "python")
    local shim_dir = join_path(target_dir, "bin")
    local script_dir = is_win and "Scripts" or "bin"
    local exe_ext = is_win and ".exe" or ""
    local python_bin = join_path(venv_dir, script_dir .. (is_win and "\\python" or "/python") .. exe_ext)
    local shim_exe = join_path(shim_dir, "unsloth" .. exe_ext)
    local shim_bat = join_path(shim_dir, "unsloth.bat")
    local shim_sh = join_path(shim_dir, "unsloth")

    -- Fast-path idempotency check (matching Section 1)
    if test_path(python_bin) and (test_path(shim_exe) or test_path(shim_bat) or test_path(shim_sh)) then
        return
    end

    local function run_cmd(cmd)
        local code = os.execute(cmd)
        if code ~= 0 and code ~= true then
            error(string.format("[unsloth] Command failed with exit code %s: %s", tostring(code), cmd))
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

    -- Locate uv (Mise managed, CLAUSE_BIN_DIR, or PATH)
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
                        log("uv is not available in PATH. Ensure 'mise install' has completed.", "FATAL")
                        error("[unsloth] Missing required tool: uv")
                    end
                end
            end
        end
    end

    if not uv_exe then
        log("uv package manager missing. Ensure 'uv' is seeded or installed via Mise.", "FATAL")
        error("[unsloth] Missing prerequisite: uv")
    end

    log("Initializing Hermetic Unsloth AI Engine Deployment (" .. version .. ")...", "INFO")

    local clause_temp_dir = os.getenv("CLAUSE_TEMP_DIR") or (is_win and (os.getenv("TEMP") or target_dir) or "/tmp")
    local clause_cache_dir = os.getenv("CLAUSE_CACHE_DIR") or join_path(target_dir, "cache")

    -- Provision target directories
    local dirs_to_provision = { target_dir, shim_dir, private_py_dir, clause_temp_dir, clause_cache_dir }
    for _, d in ipairs(dirs_to_provision) do
        if not test_path(d) then
            if is_win then
                os.execute("if not exist \"" .. d .. "\" mkdir \"" .. d .. "\" >nul 2>&1")
            else
                os.execute("mkdir -p \"" .. d .. "\"")
            end
        end
    end

    -- Confine all uv downloads and runtime stores strictly to target path
    local uv_cache_dir = join_path(clause_cache_dir, "uv")
    local uv_python_install_dir = private_py_dir

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
    -- 2. HARDWARE ACCELERATION DETECTION MATRIX (CUDA / ROCm / XPU / MPS / CPU)
    -- ==============================================================================
    local pytorch_base_url = "https://download.pytorch.org/whl"
    local torch_index_url = pytorch_base_url .. "/cpu"
    local skip_torch = false

    if is_mac then
        -- ── macOS Platform Handling ──
        local mac_arch = capture_cmd("uname -m 2>/dev/null"):gsub("[\r\n]+", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if mac_arch == "arm64" then
            log("Detected Apple Silicon (MPS / Metal acceleration).", "INFO")
            torch_index_url = pytorch_base_url .. "/cpu"
        else
            log("Intel Mac (x86_64) detected: PyTorch unsupported, running in GGUF-only mode.", "WARN")
            skip_torch = true
        end
    elseif is_win then
        -- ── Windows Platform Handling ──
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

                local sm_out = capture_cmd("nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits 2>nul")
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
                log("Pre-Turing NVIDIA GPU (sm_" .. tostring(sm_arch) .. " < sm_75) detected -> Capping to cu126.", "WARN")
                cuda_tag = "cu126"
            end

            torch_index_url = pytorch_base_url .. "/" .. cuda_tag
            log("Detected NVIDIA GPU (CUDA " .. tostring(cuda_major) .. "." .. tostring(cuda_minor) .. ") -> Target Index: " .. torch_index_url, "INFO")
        else
            -- 2. Probe AMD ROCm on Windows (Using wmic or base64 PowerShell to bypass cmd quoting failure)
            local gpu_names = capture_cmd("wmic path win32_videocontroller get name 2>nul")
            if not gpu_names:find("Name") then
                -- Base64 encoded: Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
                gpu_names = capture_cmd("powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand RwBlAHQALQBDAGkAbQBJAG4AcwB0AGEAbgBjAGUAIABXAGkAbgAzADIAXwBWAGkAZABlAG8AQwBvAG4AdAByAG8AbABsAGUAcgAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBFAHgAcABhAG4AZABQAHIAbwBwAGUAcgB0AHkAIABOAGEAbQBlAA== 2>nul")
            end

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
                    log("Detected AMD GPU (" .. rocm_gfx .. ") -> Target Index: Multi-Arch ROCm", "INFO")
                else
                    torch_index_url = "https://repo.amd.com/rocm/whl/" .. rocm_gfx .. "/"
                    log("Detected AMD GPU (" .. rocm_gfx .. ") -> Target Index: " .. torch_index_url, "INFO")
                end
            else
                -- 3. Probe Intel Arc / XPU on Windows
                local intel_gpu = false
                if gpu_names:match("Intel.*Arc") or gpu_names:match("Data Center GPU") then
                    intel_gpu = true
                end

                if intel_gpu then
                    torch_index_url = pytorch_base_url .. "/xpu"
                    log("Detected Intel Arc / XPU device -> Target Index: " .. torch_index_url, "INFO")
                else
                    log("No discrete GPU detected. Falling back to CPU PyTorch.", "WARN")
                end
            end
        end
    else
        -- ── Linux Platform Handling ──
        local nvidia_detected = false
        local cuda_major = 0
        local cuda_minor = 0
        local sm_arch = 0

        -- 1. Probe NVIDIA
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

            -- Cap pre-Turing (sm < 75) to cu126
            if sm_arch > 0 and sm_arch < 75 and (cuda_tag == "cu128" or cuda_tag == "cu130") then
                log("Pre-Turing NVIDIA GPU (sm_" .. tostring(sm_arch) .. " < sm_75) detected -> Capping to cu126.", "WARN")
                cuda_tag = "cu126"
            end

            torch_index_url = pytorch_base_url .. "/" .. cuda_tag
            log("Detected NVIDIA GPU (CUDA " .. tostring(cuda_major) .. "." .. tostring(cuda_minor) .. ") -> Target Index: " .. torch_index_url, "INFO")
        elseif test_path("/dev/kfd") or (os.execute("command -v rocminfo >/dev/null 2>&1") == 0) then
            -- 2. Probe AMD ROCm on Linux
            local rocm_tag = "rocm6.2"
            if os.execute("command -v rocminfo >/dev/null 2>&1") == 0 then
                local rocm_info = capture_cmd("rocminfo 2>/dev/null")
                local maj_min = rocm_info:match("ROCm Version:%s*(%d+%.%d+)")
                if maj_min then
                    rocm_tag = "rocm" .. maj_min
                end
            end
            torch_index_url = pytorch_base_url .. "/" .. rocm_tag
            log("Detected AMD ROCm Acceleration (" .. rocm_tag .. ") -> Target Index: " .. torch_index_url, "INFO")
        elseif test_path("/dev/dri") then
            -- 3. Probe Intel Arc / XPU on Linux
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
                log("Detected Intel Arc / XPU acceleration -> Target Index: " .. torch_index_url, "INFO")
            else
                log("No supported GPU found. Falling back to CPU PyTorch.", "WARN")
            end
        else
            log("No GPU detected. Falling back to CPU PyTorch.", "WARN")
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

    -- Filesystem fallback if uv output contained warnings or carriage returns
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
            local p_scan = capture_cmd(string.format('find "%s" -type f \\( -name "python3.12" -o -name "python3" \\) 2>/dev/null', private_py_dir))
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

    -- ==============================================================================
    -- 4. ASSEMBLE VIRTUAL ENVIRONMENT & RUNTIMES
    -- ==============================================================================
    if not test_path(python_bin) then
        log("Creating Unsloth virtual environment at " .. venv_dir .. "...", "DEBUG")
        run_uv(string.format("venv \"%s\" --python \"%s\"", venv_dir, base_python))
    end

    -- Mark environment ownership
    local ownership_marker = join_path(venv_dir, ".unsloth-studio-owned")
    local f_mark = io.open(ownership_marker, "w")
    if f_mark then
        f_mark:write("")
        f_mark:close()
    end

    -- ==============================================================================
    -- 5. INSTALL PYTORCH FOUNDATION & CORE DEPENDENCIES
    -- ==============================================================================
    if not skip_torch then
        log("Installing PyTorch runtime from " .. torch_index_url .. "...", "INFO")
        run_uv(string.format(
            "pip install --python \"%s\" --default-index \"%s\" \"torch>=2.4.0,<2.12.0\" \"torchvision>=0.19.0,<0.27.0\" \"torchaudio>=2.4.0,<2.12.0\"",
            python_bin, torch_index_url
        ))

        -- If Intel XPU was chosen, inject XPU bitsandbytes
        if torch_index_url:find("/xpu") then
            log("Installing Intel XPU bitsandbytes extension...", "DEBUG")
            run_uv(string.format("pip install --python \"%s\" --no-deps \"bitsandbytes>=0.50.0\"", python_bin))
        end

        -- Pin PyTorch versions to overrides file to prevent unsloth dependency downgrade
        local py_query = string.format("\"%s\" -c \"import importlib.metadata as m; print(m.version('torch'))\"", python_bin)
        local installed_torch = capture_cmd(py_query):gsub("[\r\n]+", ""):gsub("%s+", "")
        local override_file = join_path(clause_temp_dir, "torch_override_" .. tostring(os.time()) .. ".txt")

        local f_over = io.open(override_file, "w")
        if f_over then
            f_over:write("torch==" .. installed_torch .. "\ntorchvision\ntorchaudio\n")
            f_over:close()
        end

        local install_ok, install_err = pcall(function()
            log("Installing Unsloth Core (" .. version .. ") locked to PyTorch " .. installed_torch .. "...", "INFO")
            run_uv(string.format(
                "pip install --python \"%s\" --overrides \"%s\" \"unsloth==%s\" \"unsloth-zoo\"",
                python_bin, override_file, version
            ))
        end)

        if test_path(override_file) then
            os.remove(override_file)
        end

        if not install_ok then
            error(install_err)
        end
    else
        log("Installing Unsloth Core (" .. version .. ") in No-Torch Mode...", "INFO")
        run_uv(string.format("pip install --python \"%s\" --no-deps \"unsloth==%s\" \"unsloth-zoo\"", python_bin, version))
        run_uv(string.format("pip install --python \"%s\" \"pydantic\"", python_bin))
    end

    -- ==============================================================================
    -- 6. GENERATE CLI TRAMPOLINES (APPLICATION CONTROL & HERMETIC BYPASS)
    -- ==============================================================================
    local trampoline_code = 'import sys, os; sys.argv[0] = "unsloth"; from unsloth_cli import app; sys.exit(app())'

    if is_win then
        -- Generate CMD trampoline to bypass AppLocker / WDAC
        local cmd_shim = join_path(shim_dir, "unsloth.bat")
        local f_cmd = io.open(cmd_shim, "w")
        if f_cmd then
            f_cmd:write("@echo off\r\nsetlocal\r\n")
            f_cmd:write("\"%~dp0..\\venv\\Scripts\\python.exe\" -X utf8 -c \"" .. trampoline_code:gsub('"', '\\"') .. "\" %*\r\n")
            f_cmd:write("exit /b %ERRORLEVEL%\r\n")
            f_cmd:close()
        end
    else
        -- Generate POSIX shell trampoline
        local sh_shim = join_path(shim_dir, "unsloth")
        local f_sh = io.open(sh_shim, "w")
        if f_sh then
            f_sh:write("#!/usr/bin/env sh\n")
            f_sh:write("exec \"$(dirname \"$0\")/../venv/bin/python\" -c '" .. trampoline_code .. "' \"$@\"\n")
            f_sh:close()
        end
        os.execute("chmod +x \"" .. sh_shim .. "\"")
    end

    log("Unsloth AI Engine successfully provisioned.", "INFO")
end