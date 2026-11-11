#!/usr/bin/env sh
# ==============================================================================
# CARRIER / CLAUSE OS - NATIVE POSIX ENTRY POINT & MICROKERNEL BOOTLOADER
# ==============================================================================
set -e

# ==============================================================================
# RESOLVE ROOT & LOAD CANONICAL ENVIRONMENT FROM .ENV (SSOT)
# ==============================================================================
# 1. Base Anchors
if [ -z "$CLAUSE_PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
    export CLAUSE_PROJECT_ROOT="$PROJECT_ROOT"
else
    PROJECT_ROOT="$CLAUSE_PROJECT_ROOT"
fi

DOTENV_FILE="${PROJECT_ROOT}/.env"
if [ ! -f "$DOTENV_FILE" ]; then
    echo "[ClauseOS] Critical: Canonical environment file missing at $DOTENV_FILE" >&2
    exit 1
fi

# Ingest the Single Source of Truth (.env file)
# Ignores commented lines and blank lines while preserving key=value pairs
while IFS='=' read -r key val || [ -n "$key" ]; do
    case "$key" in
        \#*|"") continue ;;
        *)
            # Strip outer quotes and spaces if present
            clean_val=$(echo "$val" | sed -e 's/^[[:space:]]*["'\'']\{0,1\}//' -e 's/["'\'']\{0,1\}[[:space:]]*$//')
            eval "export $key=\"$clean_val\""
            ;;
    esac
done < "$DOTENV_FILE"

# ------------------------------------------------------------------------------
# CRITICAL: Scrub all Windows NT platform keys from the POSIX process environment.
# Ensures that child processes, tools, and Nushell do not inherit WIN_* paths
# on Linux/macOS runtimes.
# ------------------------------------------------------------------------------
unset WIN_LOCALAPPDATA \
      WIN_APPDATA \
      WIN_CLAUSE_BIN_DIR \
      WIN_CLAUSE_APPS_DIR \
      WIN_CLAUSE_LOGS_DIR \
      WIN_CLAUSE_TEMP_DIR \
      WIN_CLAUSE_CACHE_DIR

# 2. Confinement Anchors
export CLAUSE_HOME="${PROJECT_ROOT}/${CLAUSE_HOME:-.home}"
export HOME="$CLAUSE_HOME"
export USERPROFILE="$CLAUSE_HOME"

# 3. Platform Hierarchy (POSIX XDG Standards inside .home)
export XDG_CONFIG_HOME="${PROJECT_ROOT}/${XDG_CONFIG_HOME}"
export XDG_DATA_HOME="${PROJECT_ROOT}/${XDG_DATA_HOME}"
export XDG_STATE_HOME="${PROJECT_ROOT}/${XDG_STATE_HOME}"
export XDG_CACHE_HOME="${PROJECT_ROOT}/${XDG_CACHE_HOME}"

export CLAUSE_BIN_DIR="${PROJECT_ROOT}/${POSIX_CLAUSE_BIN_DIR}"
export CLAUSE_APPS_DIR="${PROJECT_ROOT}/${POSIX_CLAUSE_APPS_DIR}"
export CLAUSE_CACHE_DIR="${XDG_CACHE_HOME}"
export CLAUSE_TEMP_DIR="${XDG_CACHE_HOME}/tmp_bootstrap"
export CLAUSE_LOGS_DIR="${PROJECT_ROOT}/${POSIX_CLAUSE_LOGS_DIR}"

# Ensure core directories and hermetic .ssh exist on disk
SSH_DIR="${CLAUSE_HOME}/.ssh"
[ -d "${CLAUSE_CACHE_DIR}" ] || mkdir -p "${CLAUSE_CACHE_DIR}"
[ -d "${CLAUSE_BIN_DIR}" ] || mkdir -p "${CLAUSE_BIN_DIR}"
[ -d "${CLAUSE_LOGS_DIR}" ] || mkdir -p "${CLAUSE_LOGS_DIR}"
[ -d "${SSH_DIR}" ] || mkdir -p "${SSH_DIR}"

# Application Profile Targets
export GIT_CONFIG_GLOBAL="${PROJECT_ROOT}/${GIT_CONFIG_GLOBAL}"
export GH_CONFIG_DIR="${XDG_CONFIG_HOME}/gh"
export NU_CONFIG_DIR="${PROJECT_ROOT}/${NU_CONFIG_DIR}"
export PULUMI_HOME="${PROJECT_ROOT}/${PULUMI_HOME}"

# Strict Git & SSH Environment Locks
SSH_CONFIG="${SSH_DIR}/config"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"

if [ -f "$SSH_CONFIG" ]; then
    export GIT_SSH_COMMAND="ssh -F '$SSH_CONFIG' -o UserKnownHostsFile='$KNOWN_HOSTS'"
else
    export GIT_SSH_COMMAND="ssh -i '$SSH_DIR/id_ed25519' -i '$SSH_DIR/id_rsa' -o UserKnownHostsFile='$KNOWN_HOSTS'"
fi

# Hermetic SSH invocation proxy
ssh() {
    if [ -f "$CLAUSE_HOME/.ssh/config" ]; then
        command ssh -F "$CLAUSE_HOME/.ssh/config" "$@"
    else
        command ssh "$@"
    fi
}

# Isolated Toolchain Directories (Mise paths on POSIX)
export MISE_DATA_DIR="${XDG_DATA_HOME}/mise"
export MISE_CONFIG_DIR="${XDG_CONFIG_HOME}/mise"
export MISE_STATE_DIR="${XDG_STATE_HOME}/mise"
export MISE_CACHE_DIR="${XDG_CACHE_HOME}/mise"
export MISE_LOG_FILE="${CLAUSE_LOGS_DIR}/mise.log"
export MISE_LOG_FILE_LEVEL="${MISE_LOG_FILE_LEVEL:-trace}"

# Enforce CLAUSE_BIN_DIR Prepend Only
case ":${PATH}:" in
    *:"${CLAUSE_BIN_DIR}":*) ;;
    *) export PATH="${CLAUSE_BIN_DIR}:${PATH}" ;;
esac

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
# MODULAR RECIPE DISCOVERY & EXECUTION (STAGE 0 & STAGE 1)
# ==============================================================================
INSTALLER_DIR="${PROJECT_ROOT}/${POSIX_INSTALLERS_DIR}"

if [ -d "$INSTALLER_DIR" ]; then
    for recipe in "$INSTALLER_DIR"/installer_*.sh; do
        [ -e "$recipe" ] || continue

        base_name="$(basename "$recipe" .sh)"
        tool_key="$(echo "$base_name" | sed -E 's/^([0-9]+_)?installer_//')"

        version="$(get_toml_value "$tool_key")"
        if [ -z "$version" ]; then
            write_clause_log "Missing required version definition for '$tool_key' in .clause.toml" "FATAL"
            exit 1
        fi

        chmod +x "$recipe"

        # Export/set for the recipe to consume directly
        VERSION="$version"
        RECIPE_PATH="$recipe"

        . "$recipe"
    done
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
    "$NU_BIN" -c "with-env { MISE_DISABLE_TOOLS: '1' } { ^'$MISE_BIN' activate nu | save '$MISE_NU' --force }" || {
        write_clause_log "Failed to sync Mise overlay with Nushell" "ERROR"
    }
fi

# ==============================================================================
# STAGE 2: TOOLCHAIN INSTALLATION & HEALTH VERIFICATION (MISE)
# ==============================================================================
write_clause_log "Finalizing ClauseOS toolchain installation..." "INFO"
"$MISE_BIN" install --yes

MISE_SHIMS="${CLAUSE_HOME}/.local/share/mise/shims"
if [ -d "$MISE_SHIMS" ]; then
    case ":${PATH}:" in
        *:"${MISE_SHIMS}":*) ;;
        *) export PATH="${MISE_SHIMS}:${PATH}" ;;
    esac
fi

# --- Direct Filesystem Probe for Engine Directories (POSIX Compliant) ---
REQUIRED_TOOLS="comfyui lemonade code fastflowlm unsloth"
MISSING_TOOLS=""
MISE_INSTALLS_BASE="${CLAUSE_HOME}/.local/share/mise/installs"

write_clause_log "Probing tool installations at: ${MISE_INSTALLS_BASE}" "DEBUG"

for tool in $REQUIRED_TOOLS; do
    tool_dir="${MISE_INSTALLS_BASE}/${tool}"
    installed=0

    if [ -d "$tool_dir" ]; then
        # Check if directory contains at least one version folder/file
        if [ -n "$(ls -A "$tool_dir" 2>/dev/null)" ]; then
            installed=1
        fi
    fi

    if [ "$installed" -eq 0 ]; then
        if [ -z "$MISSING_TOOLS" ]; then
            MISSING_TOOLS="$tool"
        else
            MISSING_TOOLS="${MISSING_TOOLS} $tool"
        fi
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    write_clause_log "Missing toolchain engines detected: ${MISSING_TOOLS}. Re-executing mise install..." "WARN"
    "$MISE_BIN" install --yes || {
        write_clause_log "Mise retry installation failed" "FATAL"
        exit 1
    }
else
    write_clause_log "All engines verified successfully." "INFO"
fi

# ==============================================================================
# STAGE 3: NUSHELL HANDOFF (CLI, CI/CD NON-INTERACTIVE, & TTY ROUTING)
# ==============================================================================
cd "$PROJECT_ROOT"

ENV_NU="${PROJECT_ROOT}/scripts/cli/nu/core/boot.nu"
CONFIG_NU="${NU_CONFIG_DIR}/config.nu"

IS_NON_INTERACTIVE=0
# If checking if CI is enabled:
if [ "${CI:-false}" = "true" ]; then
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
    write_clause_log "Nushell executable missing at $NU_BIN." "FATAL"
    exit 1
fi