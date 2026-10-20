#!/bin/sh
# clause.sh - POSIX Stage 0 Microkernel & Confined Profile Bootloader
set -e

PROJECT_ROOT="${CLAUSE_PROJECT_ROOT:-$(pwd -P 2>/dev/null || pwd)}"

# ==============================================================================
# PRE-BOOT ENVIRONMENT LOCKING
# ==============================================================================
ENV_SH="$PROJECT_ROOT/.config/sh/env.sh"
if [ -f "$ENV_SH" ]; then
    . "$ENV_SH"
fi

LOCAL_BIN="$PROJECT_ROOT/.local/bin"
APP_DIR="$PROJECT_ROOT/.local/app"
CACHE_DIR="$PROJECT_ROOT/.cache"
TMP_DIR="$CACHE_DIR/tmp_bootstrap"
MANIFEST="$PROJECT_ROOT/.clause.toml"
NU_CONFIG_DIR="$PROJECT_ROOT/.config/nushell"

# Target Application Directories
INFERENCE_GPU_DIR="$APP_DIR/lemonade"
INFERENCE_NPU_DIR="$APP_DIR/fastflowlm"
APM_DIR="$APP_DIR/apm"
CODE_DIR="$APP_DIR/vscode"

if [ ! -f "$MANIFEST" ]; then
    echo "[ClauseOS] Error: Manifest file not found at $MANIFEST"
    exit 1
fi

parse_toml_var() {
    key="$1"
    sed -n 's/^[[:space:]]*'"$key"'[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -n 1
}

MISE_VER="$(parse_toml_var "mise")"
JUST_VER="$(parse_toml_var "just")"
NU_VER="$(parse_toml_var "nu")"
LEMONADE_VER="$(parse_toml_var "lemonade")"
FASTFLOW_VER="$(parse_toml_var "fastflowlm")"
APM_VER="$(parse_toml_var "apm")"
VSCODE_VER="$(parse_toml_var "vscode")"
VSCODE_BUILD_ID="$(parse_toml_var "vscode_build_id")"

if [ -z "$MISE_VER" ] || [ -z "$JUST_VER" ] || [ -z "$NU_VER" ] || [ -z "$LEMONADE_VER" ] || [ -z "$FASTFLOW_VER" ] || [ -z "$APM_VER" ] || [ -z "$VSCODE_VER" ]; then
    echo "[ClauseOS] Error: Missing required version definitions in .clause.toml"
    exit 1
fi

# Version Sanitizers
LEMONADE_TAG="$(echo "$LEMONADE_VER" | grep -E '^v' || echo "v$LEMONADE_VER")"
LEMONADE_CLEAN="$(echo "$LEMONADE_TAG" | sed 's/^v//')"
FASTFLOW_TAG="$(echo "$FASTFLOW_VER" | grep -E '^v' || echo "v$FASTFLOW_VER")"
FASTFLOW_CLEAN="$(echo "$FASTFLOW_TAG" | sed 's/^v//')"
APM_TAG="$(echo "$APM_VER" | grep -E '^v' || echo "v$APM_VER")"

mkdir -p "$LOCAL_BIN" "$APP_DIR" "$TMP_DIR" "$INFERENCE_GPU_DIR" "$INFERENCE_NPU_DIR" "$APM_DIR" "$CODE_DIR" "$NU_CONFIG_DIR"

OS="$(uname -s)"
case "$OS" in
    Linux)
        MISE_ASSET="mise-v${MISE_VER}-linux-x64.tar.gz"
        JUST_ASSET="just-${JUST_VER}-x86_64-unknown-linux-musl.tar.gz"
        NU_ASSET="nu-${NU_VER}-x86_64-unknown-linux-gnu.tar.gz"
        LEMONADE_ASSET="lemonade-embeddable-${LEMONADE_CLEAN}-ubuntu-x64.tar.gz"
        FASTFLOW_ASSET="fastflowlm_${FASTFLOW_CLEAN}_linux.tar.gz"
        APM_ASSET="apm-linux-x86_64.tar.gz"
        CODE_ASSET="code-stable-x64-${VSCODE_BUILD_ID}.tar.gz"
        CODE_URL="https://update.code.visualstudio.com/${VSCODE_VER}/linux-x64/stable"
        ;;
    Darwin)
        MISE_ASSET="mise-v${MISE_VER}-macos-x64.tar.gz"
        JUST_ASSET="just-${JUST_VER}-x86_64-apple-darwin.tar.gz"
        NU_ASSET="nu-${NU_VER}-x86_64-apple-darwin.tar.gz"
        LEMONADE_ASSET="lemonade-embeddable-${LEMONADE_CLEAN}-macos-arm64.tar.gz"
        FASTFLOW_ASSET="" # NPU FastFlowLM skipped on macOS
        APM_ASSET="apm-darwin-x86_64.tar.gz"
        CODE_ASSET="VSCode-darwin-universal.dmg"
        CODE_URL="https://update.code.visualstudio.com/${VSCODE_VER}/darwin-universal-dmg/stable"
        ;;
    *)
        echo "[ClauseOS] Unsupported POSIX OS: $OS"
        exit 1
        ;;
esac

download_file() {
    url="$1"
    dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    else
        echo "[ClauseOS] Error: Neither curl nor wget is available."
        exit 1
    fi
}

deploy_extracted_archive() {
    src_dir="$1"
    dest_dir="$2"
    mkdir -p "$dest_dir"
    subdirs_count="$(find "$src_dir" -mindepth 1 -maxdepth 1 | wc -l)"
    first_item="$(find "$src_dir" -mindepth 1 -maxdepth 1)"
    if [ "$subdirs_count" -eq 1 ] && [ -d "$first_item" ]; then
        cp -R "$first_item"/* "$dest_dir/"
    else
        cp -R "$src_dir"/* "$dest_dir/"
    fi
}

# ==============================================================================
# STAGE 0: CORE SYSTEM ENGINE SEEDING
# ==============================================================================

# 1. Mise Engine -> .local/bin/
if [ ! -f "$LOCAL_BIN/mise" ]; then
    echo "[ClauseOS Stage 0] Pre-seeding Mise (v${MISE_VER}) into .local/bin/..."
    download_file "https://github.com/jdx/mise/releases/download/v${MISE_VER}/$MISE_ASSET" "$TMP_DIR/$MISE_ASSET"
    MISE_TMP_EXTRACT="$TMP_DIR/mise_extract"
    mkdir -p "$MISE_TMP_EXTRACT"
    tar -xzf "$TMP_DIR/$MISE_ASSET" -C "$MISE_TMP_EXTRACT"
    
    FOUND_MISE="$(find "$MISE_TMP_EXTRACT" -name "mise" -type f | head -n 1)"
    if [ -n "$FOUND_MISE" ]; then
        cp "$FOUND_MISE" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/mise"
    fi
fi

# 2. Just Task Scheduler -> .local/bin/
if [ ! -f "$LOCAL_BIN/just" ]; then
    echo "[ClauseOS Stage 0] Pre-seeding Just (v${JUST_VER}) into .local/bin/..."
    download_file "https://github.com/casey/just/releases/download/${JUST_VER}/$JUST_ASSET" "$TMP_DIR/$JUST_ASSET"
    JUST_TMP_EXTRACT="$TMP_DIR/just_extract"
    mkdir -p "$JUST_TMP_EXTRACT"
    tar -xzf "$TMP_DIR/$JUST_ASSET" -C "$JUST_TMP_EXTRACT"
    
    FOUND_JUST="$(find "$JUST_TMP_EXTRACT" -name "just" -type f | head -n 1)"
    if [ -n "$FOUND_JUST" ]; then
        cp "$FOUND_JUST" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/just"
    fi
fi

# 3. Nushell Shell Engine -> .local/bin/
if [ ! -f "$LOCAL_BIN/nu" ]; then
    echo "[ClauseOS Stage 0] Pre-seeding Nushell (v${NU_VER}) into .local/bin/..."
    download_file "https://github.com/nushell/nushell/releases/download/${NU_VER}/$NU_ASSET" "$TMP_DIR/$NU_ASSET"
    NU_TMP_EXTRACT="$TMP_DIR/nu_extract"
    mkdir -p "$NU_TMP_EXTRACT"
    tar -xzf "$TMP_DIR/$NU_ASSET" -C "$NU_TMP_EXTRACT"
    
    FOUND_NU="$(find "$NU_TMP_EXTRACT" -name "nu" -type f | head -n 1)"
    if [ -n "$FOUND_NU" ]; then
        cp "$FOUND_NU" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/nu"
    fi
fi

# ==============================================================================
# STAGE 1: PORTABLE APPS & AI COMPONENT SEEDING
# ==============================================================================

# 4. Lemonade GPU Engine -> .local/app/lemonade/
if [ ! -f "$INFERENCE_GPU_DIR/lemonade" ]; then
    echo "[ClauseOS Stage 1] Seeding Lemonade GPU Engine (${LEMONADE_TAG})..."
    download_file "https://github.com/lemonade-sdk/lemonade/releases/download/${LEMONADE_TAG}/${LEMONADE_ASSET}" "$TMP_DIR/$LEMONADE_ASSET"
    LEMONADE_TMP_EXTRACT="$TMP_DIR/lemonade_extract"
    mkdir -p "$LEMONADE_TMP_EXTRACT"
    tar -xzf "$TMP_DIR/$LEMONADE_ASSET" -C "$LEMONADE_TMP_EXTRACT"
    deploy_extracted_archive "$LEMONADE_TMP_EXTRACT" "$INFERENCE_GPU_DIR"
    chmod +x "$INFERENCE_GPU_DIR/lemonade" 2>/dev/null || true
fi

# 5. FastFlowLM NPU Engine -> .local/app/fastflowlm/
if [ -n "$FASTFLOW_ASSET" ] && [ ! -f "$INFERENCE_NPU_DIR/fastflowlm" ]; then
    echo "[ClauseOS Stage 1] Seeding FastFlowLM NPU Engine (${FASTFLOW_TAG})..."
    download_file "https://github.com/ROCm/FastFlowLM/releases/download/${FASTFLOW_TAG}/${FASTFLOW_ASSET}" "$TMP_DIR/$FASTFLOW_ASSET"
    FASTFLOW_TMP_EXTRACT="$TMP_DIR/fastflow_extract"
    mkdir -p "$FASTFLOW_TMP_EXTRACT"
    tar -xzf "$TMP_DIR/$FASTFLOW_ASSET" -C "$FASTFLOW_TMP_EXTRACT"
    deploy_extracted_archive "$FASTFLOW_TMP_EXTRACT" "$INFERENCE_NPU_DIR"
    chmod +x "$INFERENCE_NPU_DIR/fastflowlm" 2>/dev/null || true
fi

# 6. APM (Agent Package Manager) -> .local/app/apm/
if [ ! -f "$APM_DIR/apm" ]; then
    echo "[ClauseOS Stage 1] Seeding Agent Package Manager (${APM_TAG})..."
    download_file "https://github.com/microsoft/apm/releases/download/${APM_TAG}/${APM_ASSET}" "$TMP_DIR/$APM_ASSET"
    APM_TMP_EXTRACT="$TMP_DIR/apm_extract"
    mkdir -p "$APM_TMP_EXTRACT"
    tar -xzf "$TMP_DIR/$APM_ASSET" -C "$APM_TMP_EXTRACT"
    deploy_extracted_archive "$APM_TMP_EXTRACT" "$APM_DIR"
    chmod +x "$APM_DIR/apm" 2>/dev/null || true
fi

# 7. VS Code Portable -> .local/app/vscode/
if [ ! -f "$CODE_DIR/bin/code" ] && [ ! -d "$CODE_DIR/Visual Studio Code.app" ]; then
    echo "[ClauseOS Stage 1] Seeding VS Code Portable Engine (v${VSCODE_VER})..."
    download_file "$CODE_URL" "$TMP_DIR/$CODE_ASSET"

    if [ "$OS" = "Darwin" ]; then
        MOUNT_POINT="$TMP_DIR/vscode_mount"
        mkdir -p "$MOUNT_POINT"
        hdiutil attach "$TMP_DIR/$CODE_ASSET" -mountpoint "$MOUNT_POINT" -nobrowse -quiet
        cp -R "$MOUNT_POINT/Visual Studio Code.app" "$CODE_DIR/"
        hdiutil detach "$MOUNT_POINT" -quiet || true
    else
        CODE_TMP_EXTRACT="$TMP_DIR/code_extract"
        mkdir -p "$CODE_TMP_EXTRACT"
        tar -xzf "$TMP_DIR/$CODE_ASSET" -C "$CODE_TMP_EXTRACT"
        deploy_extracted_archive "$CODE_TMP_EXTRACT" "$CODE_DIR"
    fi
    mkdir -p "$CODE_DIR/data"
fi

rm -rf "$TMP_DIR"

# ==============================================================================
# STAGE 2: NUSHELL HANDOFF (CLI, CI/CD NON-INTERACTIVE, & TTY ROUTING)
# ==============================================================================
NU_EXE="$LOCAL_BIN/nu"
ENV_NU="$PROJECT_ROOT/scripts/cli/nu/core/boot.nu"
CONFIG_NU="$NU_CONFIG_DIR/config.nu"

if [ -f "$NU_EXE" ] && [ -x "$NU_EXE" ]; then
    if [ -f "$ENV_NU" ]; then
        if [ "$#" -gt 0 ]; then
            exec "$NU_EXE" --env-config "$ENV_NU" -c "clause $*"
        elif [ ! -t 0 ] || [ "${CI:-false}" = "true" ]; then
            exec "$NU_EXE" --env-config "$ENV_NU" -c "clause boot:check"
        else
            if [ -f "$CONFIG_NU" ]; then
                exec "$NU_EXE" --env-config "$ENV_NU" --config "$CONFIG_NU" -e "clause banner"
            else
                exec "$NU_EXE" --env-config "$ENV_NU" -e "clause banner"
            fi
        fi
    else
        printf " \033[33mWARN\033[0m Environment file not found at %s. Booting default Nushell shell...\n" "$ENV_NU"
        exec "$NU_EXE"
    fi
else
    printf " \033[31mFAIL\033[0m Nushell (nu) could not be located in .local/bin.\n"
    exit 1
fi