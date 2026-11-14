#!/usr/bin/env sh
# ==============================================================================
# CARRIER / CLAUSE OS - NATIVE POSIX ENTRY POINT & MICROKERNEL BOOTLOADER
# ==============================================================================
set -e

# ==============================================================================
# RESOLVE ROOT & LOAD CANONICAL ENVIRONMENT FROM MODULAR TOML (SSOT)
# ==============================================================================
# 1. Base Anchors
if [ -z "$CLAUSE_PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
    export CLAUSE_PROJECT_ROOT="$PROJECT_ROOT"
else
    PROJECT_ROOT="$CLAUSE_PROJECT_ROOT"
fi

_CALLER_MISE_ENV="${MISE_ENV:-}"

ENV_CONFIG_DIR="${PROJECT_ROOT}/config/env"
if [ ! -d "$ENV_CONFIG_DIR" ]; then
    echo "[ClauseOS] Critical: Modular environment directory missing at $ENV_CONFIG_DIR" >&2
    exit 1
fi

normalize_clause_path() {
    _val="$1"
    case "$_val" in
        ""|/*|*://*)
            printf '%s' "$_val"
            ;;
        */*|.home|.clause.toml)
            printf '%s/%s' "$PROJECT_ROOT" "$_val"
            ;;
        *)
            printf '%s' "$_val"
            ;;
    esac
    unset _val
}

expand_clause_string() {
    _str="$1"
    _iter=0
    while [ "$_iter" -lt 8 ]; do
        case "$_str" in
            *'${'*'}'*)
                _prefix="${_str%%\$\{*}"
                _rest="${_str#*\$\{}"
                _var="${_rest%%\}*}"
                _suffix="${_rest#*\}}"
                case "$_var" in
                    ""|[0-9]*|*[!a-zA-Z0-9_]*)
                        break
                        ;;
                    *)
                        eval "_isset=\${_CLAUSE_ANCHOR_${_var}+1}\${${_var}+1}"
                        if [ -n "$_isset" ]; then
                            eval "_vval=\${_CLAUSE_ANCHOR_${_var}-\${${_var}-}}"
                            _str="${_prefix}${_vval}${_suffix}"
                        else
                            break
                        fi
                        ;;
                esac
                ;;
            *) break ;;
        esac
        _iter=$((_iter + 1))
    done
    printf '%s' "$_str"
    unset _str _iter _prefix _rest _var _suffix _isset _vval
}

_CLAUSE_ENV_KEYS=""
_CLAUSE_PROV_KEYS=""
_found_toml=0

# Pass 1: Ingest raw anchors, env, and provision keys for POSIX only
for _mod in "$ENV_CONFIG_DIR"/*.toml; do
    [ -f "$_mod" ] || continue
    _found_toml=1
    _section=""

    while IFS= read -r _line || [ -n "$_line" ]; do
        _line="${_line%$(printf '\r')}"
        _line="${_line#"${_line%%[![:space:]]*}"}"

        case "$_line" in
            ""|\#*) continue ;;
        esac

        case "$_line" in
            \[*\])
                _section="${_line#\[}"
                _section="${_section%%\]*}"
                continue
                ;;
        esac

        case "$_line" in
            *=*) ;;
            *) continue ;;
        esac

        case "$_section" in
            anchors.posix|env|env.posix|provision|provision.posix) ;;
            *) continue ;;
        esac

        _key="${_line%%=*}"
        _val="${_line#*=}"

        _key="${_key%"${_key##*[![:space:]]}"}"
        _val="${_val#"${_val%%[![:space:]]*}"}"

        case "$_key" in
            ""|[0-9]*|*[!a-zA-Z0-9_]*) continue ;;
        esac

        case "$_val" in
            \"*\")
                _val="${_val#\"}"
                _val="${_val%\"}"
                ;;
            \'*\')
                _val="${_val#\'}"
                _val="${_val%\'}"
                ;;
            *)
                _val="${_val%%[[:space:]]\#*}"
                _val="${_val%"${_val##*[![:space:]]}"}"
                ;;
        esac

        case "$_section" in
            anchors.posix)
                eval "_CLAUSE_ANCHOR_${_key}=\"\$_val\""
                ;;
            env|env.posix)
                export "${_key}=${_val}"
                case " ${_CLAUSE_ENV_KEYS} " in
                    *" ${_key} "*) ;;
                    *) _CLAUSE_ENV_KEYS="${_CLAUSE_ENV_KEYS} ${_key}" ;;
                esac
                ;;
            provision|provision.posix)
                eval "_CLAUSE_PROV_${_key}=\"\$_val\""
                case " ${_CLAUSE_PROV_KEYS} " in
                    *" ${_key} "*) ;;
                    *) _CLAUSE_PROV_KEYS="${_CLAUSE_PROV_KEYS} ${_key}" ;;
                esac
                ;;
        esac
    done < "$_mod"
done

if [ "$_found_toml" -eq 0 ]; then
    echo "[ClauseOS] Critical: No TOML environment modules found in $ENV_CONFIG_DIR" >&2
    exit 1
fi

# Pass 2: Normalize anchors, iteratively resolve env vars, and provision directories
for _avar in $(set | sed -n 's/^\(_CLAUSE_ANCHOR_[a-zA-Z0-9_]*\)=.*/\1/p'); do
    eval "_aval=\$$_avar"
    _aval="$(normalize_clause_path "$_aval")"
    eval "${_avar}=\"\$_aval\""
done

_pass=0
while [ "$_pass" -lt 8 ]; do
    _changed=0
    for _ekey in $_CLAUSE_ENV_KEYS; do
        eval "_cur=\$$_ekey"
        _exp="$(expand_clause_string "$_cur")"
        _exp="$(normalize_clause_path "$_exp")"
        if [ "$_exp" != "$_cur" ]; then
            export "${_ekey}=${_exp}"
            _changed=1
        fi
    done
    [ "$_changed" -eq 0 ] && break
    _pass=$((_pass + 1))
done

# Preserve explicit caller MISE_ENV override if supplied
if [ -n "$_CALLER_MISE_ENV" ]; then
    export MISE_ENV="$_CALLER_MISE_ENV"
fi

for _pkey in $_CLAUSE_PROV_KEYS; do
    eval "_pval=\$_CLAUSE_PROV_${_pkey}"
    _pdir="$(expand_clause_string "$_pval")"
    _pdir="$(normalize_clause_path "$_pdir")"
    if [ -n "$_pdir" ] && [ ! -d "$_pdir" ]; then
        mkdir -p "$_pdir"
    fi
done

# Scrub internal parser state from shell scope
for _tmpvar in $(set | sed -n 's/^\(_CLAUSE_ANCHOR_[a-zA-Z0-9_]*\|_CLAUSE_PROV_[a-zA-Z0-9_]*\)=.*/\1/p'); do
    unset "$_tmpvar"
done
unset _found_toml _mod _section _line _key _val _avar _aval _pass _changed _ekey _cur _exp _pkey _pval _pdir _tmpvar _CLAUSE_ENV_KEYS _CLAUSE_PROV_KEYS _CALLER_MISE_ENV

# Ensure core directories and hermetic .ssh exist on disk
SSH_DIR="${CLAUSE_SSH_DIR}"
[ -d "${CLAUSE_CACHE_DIR}" ] || mkdir -p "${CLAUSE_CACHE_DIR}"
[ -d "${CLAUSE_BIN_DIR}" ] || mkdir -p "${CLAUSE_BIN_DIR}"
[ -d "${CLAUSE_LOGS_DIR}" ] || mkdir -p "${CLAUSE_LOGS_DIR}"
[ -d "${SSH_DIR}" ] || mkdir -p "${SSH_DIR}"

# Strict Git & SSH Environment Locks
SSH_CONFIG="${CLAUSE_SSH_CONFIG}"
KNOWN_HOSTS="${CLAUSE_SSH_KNOWN_HOSTS}"

if [ -f "$SSH_CONFIG" ]; then
    export GIT_SSH_COMMAND="ssh -F '$SSH_CONFIG' -o UserKnownHostsFile='$KNOWN_HOSTS'"
else
    export GIT_SSH_COMMAND="ssh -i '$CLAUSE_SSH_KEY_ED25519' -i '$CLAUSE_SSH_KEY_RSA' -o UserKnownHostsFile='$KNOWN_HOSTS'"
fi

# Hermetic SSH invocation proxy
ssh() {
    if [ -f "$CLAUSE_SSH_CONFIG" ]; then
        command ssh -F "$CLAUSE_SSH_CONFIG" "$@"
    else
        command ssh "$@"
    fi
}

# Enforce CLAUSE_BIN_DIR Prepend Only
case ":${PATH}:" in
    *:"${CLAUSE_BIN_DIR}":*) ;;
    *) export PATH="${CLAUSE_BIN_DIR}:${PATH}" ;;
esac

if [ -n "${HOMEBREW_PREFIX:-}" ]; then
    case ":${PATH}:" in
        *:"${HOMEBREW_PREFIX}/bin":*) ;;
        *) export PATH="${HOMEBREW_PREFIX}/bin:${PATH}" ;;
    esac
fi

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
LOG_FILE="${CLAUSE_BOOTSTRAP_LOG}"

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
write_clause_log "Context: Root=$PROJECT_ROOT | Home=$CLAUSE_HOME | Profile=${MISE_ENV} | OS(Windows=False, Linux=$([ "$IS_LINUX" -eq 1 ] && echo True || echo False), Mac=$([ "$IS_MAC" -eq 1 ] && echo True || echo False))" "DEBUG"

# ==============================================================================
# TARGET DIRECTORY PROVISIONING
# ==============================================================================
LOCAL_BIN="${CLAUSE_BIN_DIR}"
APP_DIR="${CLAUSE_APPS_DIR}"
TMP_DIR="${CLAUSE_TEMP_DIR}"
MANIFEST="${CLAUSE_MANIFEST}"
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
INSTALLER_DIR="${INSTALLERS_DIR}"

if [ -n "$INSTALLER_DIR" ] && [ -d "$INSTALLER_DIR" ]; then
    for recipe in "$INSTALLER_DIR"/installer_*.sh; do
        [ -e "$recipe" ] || continue

        base_name="$(basename "$recipe" .sh)"
        tool_key="$(echo "$base_name" | sed -E 's/^([0-9]+_)?installer_//')"

        version="$(get_toml_value "$tool_key")"
        if [ -z "$version" ]; then
            write_clause_log "Missing required version definition for '$tool_key' in $MANIFEST" "FATAL"
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
MISE_NU="${CLAUSE_MISE_NU}"

if [ -x "$MISE_BIN" ] && [ -x "$NU_BIN" ]; then
    write_clause_log "Syncing Mise Nushell overlay..." "INFO"
    "$NU_BIN" -c "with-env { MISE_DISABLE_TOOLS: '1' } { ^'$MISE_BIN' activate nu | save '$MISE_NU' --force }" || {
        write_clause_log "Failed to sync Mise overlay with Nushell" "ERROR"
    }
fi

# ==============================================================================
# STAGE 2: TOOLCHAIN INSTALLATION & HEALTH VERIFICATION (MISE)
# ==============================================================================
write_clause_log "Finalizing ClauseOS toolchain installation (MISE_ENV=${MISE_ENV})..." "INFO"
"$MISE_BIN" install --yes

# Bootstrap POSIX system packages (Lima via Mise brew manager) only when declared in active MISE_ENV
BREW_STATUS="$("$MISE_BIN" bootstrap packages status --manager brew 2>/dev/null || true)"
if [ -n "$BREW_STATUS" ]; then
    if [ ! -x "${HOMEBREW_PREFIX}/bin/limactl" ] && ! command -v limactl >/dev/null 2>&1; then
        write_clause_log "Lima not detected; bootstrapping via Mise brew package manager..." "INFO"
        "$MISE_BIN" bootstrap packages apply --manager brew || {
            write_clause_log "Mise brew package bootstrap failed" "FATAL"
            exit 1
        }
    fi
fi

MISE_SHIMS="${MISE_SHIMS_DIR}"
if [ -n "$MISE_SHIMS" ] && [ -d "$MISE_SHIMS" ]; then
    case ":${PATH}:" in
        *:"${MISE_SHIMS}":*) ;;
        *) export PATH="${MISE_SHIMS}:${PATH}" ;;
    esac
fi

# --- Direct Filesystem Probe for Plugin Engine Directories (POSIX Compliant) ---
_ACTIVE_MANIFESTS="${PROJECT_ROOT}/.mise.toml"
if [ -n "${MISE_ENV:-}" ]; then
    _OLD_IFS="$IFS"
    IFS=','
    for _env_name in $MISE_ENV; do
        _env_name="${_env_name#"${_env_name%%[![:space:]]*}"}"
        _env_name="${_env_name%"${_env_name##*[![:space:]]}"}"
        if [ -n "$_env_name" ]; then
            _ACTIVE_MANIFESTS="${_ACTIVE_MANIFESTS} ${PROJECT_ROOT}/.mise.${_env_name}.toml ${PROJECT_ROOT}/.mise.${_env_name}.local.toml"
        fi
    done
    IFS="$_OLD_IFS"
fi
_ACTIVE_MANIFESTS="${_ACTIVE_MANIFESTS} ${PROJECT_ROOT}/.mise.local.toml"

REQUIRED_TOOLS=""
_HAS_ANY_MANIFEST=0
for _mfile in $_ACTIVE_MANIFESTS; do
    [ -f "$_mfile" ] || continue
    _HAS_ANY_MANIFEST=1
    _parsed_plugins="$(awk '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        /^[[:space:]]*\[.*\][[:space:]]*$/ {
            in_plugins = ($0 ~ /^[[:space:]]*\[plugins\][[:space:]]*$/)
            next
        }
        in_plugins && index($0, "=") > 0 {
            key = substr($0, 1, index($0, "=") - 1)
            gsub(/^[[:space:]"\x27]+|[[:space:]"\x27]+$/, "", key)
            if (key != "") print key
        }
    ' "$_mfile")"
    for _p in $_parsed_plugins; do
        case " ${REQUIRED_TOOLS} " in
            *" ${_p} "*) ;;
            *) REQUIRED_TOOLS="${REQUIRED_TOOLS:+${REQUIRED_TOOLS} }${_p}" ;;
        esac
    done
done
unset _ACTIVE_MANIFESTS _OLD_IFS _env_name _mfile _parsed_plugins _p

if [ "$_HAS_ANY_MANIFEST" -eq 0 ]; then
    REQUIRED_TOOLS="${CLAUSE_REQUIRED_ENGINES}"
fi
unset _HAS_ANY_MANIFEST

MISSING_TOOLS=""
MISE_INSTALLS_BASE="${MISE_INSTALLS_DIR}"

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

ENV_NU="${CLAUSE_BOOT_NU}"
CONFIG_NU="${CLAUSE_CONFIG_NU}"

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