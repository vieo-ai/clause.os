#!/usr/bin/env sh
# .config/sh/env.sh - ClauseOS POSIX Shell Subshell Lock

# Resolve ClauseOS root directory (2 levels up from .config/sh)
SCRIPT_DIR="$(cd "$(dirname "${ALIAS_SOURCE:-$0}")/../.." && pwd)"

export CLAUSE_PROJECT_ROOT="$SCRIPT_DIR"
export HOME="$SCRIPT_DIR"
export USERPROFILE="$SCRIPT_DIR"

# XDG Base Directories
export XDG_CONFIG_HOME="${SCRIPT_DIR}/.config"
export XDG_DATA_HOME="${SCRIPT_DIR}/.local/share"
export XDG_STATE_HOME="${SCRIPT_DIR}/.local/state"
export XDG_CACHE_HOME="${SCRIPT_DIR}/.cache"

# Windows Compatibility Environment Variables
export APPDATA="${SCRIPT_DIR}/.local/appdata"
export LOCALAPPDATA="${SCRIPT_DIR}/.local/share"

# Application Profile Targets
export GIT_CONFIG_GLOBAL="${SCRIPT_DIR}/.config/git/config"
export NU_CONFIG_DIR="${SCRIPT_DIR}/.config/nushell"
export GH_CONFIG_DIR="${SCRIPT_DIR}/.config/gh"

# Isolated Toolchain Directories
export MISE_DATA_DIR="${SCRIPT_DIR}/.cache/toolchain/mise"
export MISE_CONFIG_DIR="${SCRIPT_DIR}/.cache/toolchain/mise-config"
export MISE_STATE_DIR="${SCRIPT_DIR}/.cache/toolchain/mise-state"
export MISE_CACHE_DIR="${SCRIPT_DIR}/.cache/toolchain/mise-cache"

# Enforce .local/bin Prepend
LOCAL_BIN="${SCRIPT_DIR}/.local/bin"
case ":${PATH}:" in
    *:"${LOCAL_BIN}":*) ;;
    *) export PATH="${LOCAL_BIN}:${PATH}" ;;
esac