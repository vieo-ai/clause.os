#!/usr/bin/env sh
# cx.sh - Native POSIX Entry Point & Microkernel Bootloader for ClauseOS
set -e

# ==============================================================================
# RESOLVE ROOT & LOAD CANONICAL ENVIRONMENT
# ==============================================================================
if [ -z "$CLAUSE_PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
    export CLAUSE_PROJECT_ROOT="$PROJECT_ROOT"
else
    PROJECT_ROOT="$CLAUSE_PROJECT_ROOT"
fi

ENV_SCRIPT="${PROJECT_ROOT}/scripts/cli/sh/config/env.sh"
if [ ! -f "$ENV_SCRIPT" ]; then
    echo "[ClauseOS] Critical: Canonical environment file missing at $ENV_SCRIPT" >&2
    exit 1
fi
. "$ENV_SCRIPT"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin) IS_MAC=1; IS_LINUX=0 ;;
    Linux)  IS_MAC=0; IS_LINUX=1 ;;
    *)      IS_MAC=0; IS_LINUX=0 ;;
esac

# ==============================================================================
# LOGGING SYSTEM INITIALIZATION
# ==============================================================================
LOG_DIR="${CLAUSE_LOGS_DIR}"
LOG_FILE="${LOG_DIR}/bootstrap.log"

[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

write_clause_log() {
    msg="$1"
    lvl="${2:-INFO}"
    ts="$(date +"%Y-%m-%d %H:%M:%S")"
    entry="[$ts] [$lvl] $msg"

    echo "$entry" >> "$LOG_FILE" 2>/dev/null || true

    case "$lvl" in
        INFO)  printf "\033[36m[ClauseOS] %s\033[0m\n" "$msg" ;;
        WARN)  printf "\033[33m[ClauseOS WARN] %s\033[0m\n" "$msg" ;;
        ERROR) printf "\033[31m[ClauseOS ERROR] %s\033[0m\n" "$msg" ;;
        FATAL) printf "\033[31m\033[1m[ClauseOS FATAL] %s\033[0m\n" "$msg" ;;
        DEBUG) printf "\033[90m[ClauseOS DEBUG] %s\033[0m\n" "$msg" ;;
    esac
}

write_clause_log "Initializing ClauseOS Microkernel Bootloader..." "INFO"
write_clause_log "Context: Root=$PROJECT_ROOT | Home=$CLAUSE_HOME | OS(Windows=False, Linux=$([ "$IS_LINUX" -eq 1 ] && echo True || echo False), Mac=$([ "$IS_MAC" -eq 1 ] && echo True || echo False))" "DEBUG"

# ==============================================================================
# TARGET DIRECTORY PROVISIONING
# ==============================================================================
LOCAL_BIN="${CLAUSE_BIN_DIR}"
APP_DIR="${CLAUSE_APPS_DIR}"
TMP_DIR="${CLAUSE_TEMP_DIR}"
MANIFEST="${PROJECT_ROOT}/.clause.toml"
NU_CONFIG_DIR="${NU_CONFIG_DIR}"

if [ ! -f "$MANIFEST" ]; then
    write_clause_log "Manifest file missing at path: $MANIFEST" "FATAL"
    echo "[ClauseOS] Error: Manifest file not found at $MANIFEST" >&2
    exit 1
fi

get_toml_value() {
    key="$1"
    sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$MANIFEST" | head -n 1
}

get_file() {
    url="$1"
    out="$2"
    write_clause_log "Downloading asset: $url -> $out" "DEBUG"
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$url" -o "$out" || {
            write_clause_log "Download failed for URL '$url'" "ERROR"
            exit 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$out" "$url" || {
            write_clause_log "Download failed for URL '$url'" "ERROR"
            exit 1
        }
    else
        write_clause_log "Neither curl nor wget available" "ERROR"
        exit 1
    fi
}

expand_hermetic_archive() {
    archive="$1"
    dest="$2"
    [ -d "$dest" ] || mkdir -p "$dest"
    write_clause_log "Extracting archive: $archive -> $dest" "DEBUG"
    tar -xf "$archive" -C "$dest" || {
        write_clause_log "Archive extraction failed for '$archive'" "ERROR"
        exit 1
    }
}

mkdir -p "$LOCAL_BIN" "$APP_DIR" "$TMP_DIR" "$NU_CONFIG_DIR"

# ==============================================================================
# TWO-BINARY SEEDING (MISE & NU)
# ==============================================================================
MISE_BIN="${LOCAL_BIN}/mise"
NU_BIN="${LOCAL_BIN}/nu"

# 1. Mise Seeding
if [ ! -x "$MISE_BIN" ]; then
    MISE_VERSION="$(get_toml_value "mise")"
    if [ -z "$MISE_VERSION" ]; then
        write_clause_log "Missing required version definition for 'mise' in .clause.toml" "FATAL"
        exit 1
    fi

    CLEAN_MISE_VER="$(echo "$MISE_VERSION" | sed 's/^v//')"
    write_clause_log "Seeding Mise (v${CLEAN_MISE_VER}) into $LOCAL_BIN..." "INFO"

    if [ "$IS_MAC" -eq 1 ]; then
        case "$ARCH" in
            arm64) MISE_ASSET="mise-v${CLEAN_MISE_VER}-macos-arm64" ;;
            *)     MISE_ASSET="mise-v${CLEAN_MISE_VER}-macos-x64" ;;
        esac
    else
        case "$ARCH" in
            aarch64) MISE_ASSET="mise-v${CLEAN_MISE_VER}-linux-arm64" ;;
            *)       MISE_ASSET="mise-v${CLEAN_MISE_VER}-linux-x64" ;;
        esac
    fi

    MISE_URL="https://github.com/jdx/mise/releases/download/v${CLEAN_MISE_VER}/${MISE_ASSET}"
    get_file "$MISE_URL" "$MISE_BIN"
    chmod +x "$MISE_BIN"
fi

# 2. Nushell Seeding
if [ ! -x "$NU_BIN" ]; then
    NU_VERSION="$(get_toml_value "nu")"
    if [ -z "$NU_VERSION" ]; then
        write_clause_log "Missing required version definition for 'nu' in .clause.toml" "FATAL"
        exit 1
    fi

    CLEAN_NU_VER="$(echo "$NU_VERSION" | sed 's/^v//')"
    write_clause_log "Seeding Nushell (v${CLEAN_NU_VER}) into $LOCAL_BIN..." "INFO"

    if [ "$IS_MAC" -eq 1 ]; then
        case "$ARCH" in
            arm64) NU_TARGET="aarch64-apple-darwin" ;;
            *)     NU_TARGET="x86_64-apple-darwin" ;;
        esac
    else
        case "$ARCH" in
            aarch64) NU_TARGET="aarch64-unknown-linux-musl" ;;
            *)       NU_TARGET="x86_64-unknown-linux-musl" ;;
        esac
    fi

    NU_ASSET="nu-${CLEAN_NU_VER}-${NU_TARGET}.tar.gz"
    NU_URL="https://github.com/nushell/nushell/releases/download/${CLEAN_NU_VER}/${NU_ASSET}"
    NU_DOWNLOAD="${TMP_DIR}/${NU_ASSET}"
    NU_EXTRACT="${TMP_DIR}/nu_extracted"

    get_file "$NU_URL" "$NU_DOWNLOAD"
    expand_hermetic_archive "$NU_DOWNLOAD" "$NU_EXTRACT"

    EXTRACTED_NU="$(find "$NU_EXTRACT" -type f -name "nu" | head -n 1)"
    if [ -z "$EXTRACTED_NU" ]; then
        write_clause_log "Failed to locate extracted nu binary in $NU_EXTRACT" "FATAL"
        exit 1
    fi

    mv "$EXTRACTED_NU" "$NU_BIN"
    chmod +x "$NU_BIN"
fi

# Cleanup transient downloads
rm -rf "$TMP_DIR"
mkdir -p "$CLAUSE_TEMP_DIR"

# ==============================================================================
# GENERATE NUSHELL MISE ACTIVATION OVERLAY
# ==============================================================================
MISE_NU="${NU_CONFIG_DIR}/mise.nu"

if [ -x "$MISE_BIN" ] && [ -x "$NU_BIN" ]; then
    write_clause_log "Syncing Mise Nushell overlay..." "INFO"
    "$NU_BIN" -c "^'$MISE_BIN' activate nu | save '$MISE_NU' --force" || {
        write_clause_log "Failed to sync Mise overlay with Nushell" "ERROR"
    }
fi

# ==============================================================================
# STAGE 2: TOOLCHAIN INSTALLATION (MISE)
# ==============================================================================
write_clause_log "Finalizing ClauseOS toolchain installation..." "INFO"
"$MISE_BIN" install

MISE_SHIMS="${CLAUSE_HOME}/.local/share/mise/shims"
if [ -d "$MISE_SHIMS" ]; then
    case ":${PATH}:" in
        *:"${MISE_SHIMS}":*) ;;
        *) export PATH="${MISE_SHIMS}:${PATH}" ;;
    esac
fi

# ==============================================================================
# STAGE 3: NUSHELL HANDOFF (CLI, CI/CD NON-INTERACTIVE, & TTY ROUTING)
# ==============================================================================
cd "$PROJECT_ROOT"

ENV_NU="${PROJECT_ROOT}/scripts/cli/nu/core/boot.nu"
CONFIG_NU="${NU_CONFIG_DIR}/config.nu"

IS_NON_INTERACTIVE=0
if [ ! -t 0 ] || [ "$CI" = "true" ]; then
    IS_NON_INTERACTIVE=1
fi

write_clause_log "Performing Nushell handoff (Interactive=$([ "$IS_NON_INTERACTIVE" -eq 0 ] && echo True || echo False))..." "INFO"

if [ -x "$NU_BIN" ]; then
    if [ -f "$ENV_NU" ]; then
        if [ $# -gt 0 ]; then
            exec "$NU_BIN" --env-config "$ENV_NU" -c "clause $*"
        elif [ "$IS_NON_INTERACTIVE" -eq 1 ]; then
            exec "$NU_BIN" --env-config "$ENV_NU" -c "clause boot:check"
        else
            if [ -f "$CONFIG_NU" ]; then
                exec "$NU_BIN" --env-config "$ENV_NU" --config "$CONFIG_NU" -e "clause banner"
            else
                exec "$NU_BIN" --env-config "$ENV_NU" -e "clause banner"
            fi
        fi
    else
        write_clause_log "Environment file missing at $ENV_NU. Booting default Nushell shell..." "WARN"
        exec "$NU_BIN"
    fi
else
    write_clause_log "Nushell executable missing at $NU_Bin." "FATAL"
    exit 1
fi