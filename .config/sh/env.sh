#!/usr/bin/env sh
# .config/sh/env.sh - ClauseOS POSIX Shell Subshell Lock

# Resolve ClauseOS root directory (2 levels up from .config/sh)
CLAUSE_ROOT="$(cd "$(dirname "${ALIAS_SOURCE:-$0}")/../.." && pwd)"

export CLAUSE_PROJECT_ROOT="$CLAUSE_ROOT"
export HOME="$CLAUSE_ROOT"
export USERPROFILE="$CLAUSE_ROOT"

# XDG Base Directories
export XDG_CONFIG_HOME="${CLAUSE_ROOT}/.config"
export XDG_DATA_HOME="${CLAUSE_ROOT}/.local/share"
export XDG_STATE_HOME="${CLAUSE_ROOT}/.local/state"
export XDG_CACHE_HOME="${CLAUSE_ROOT}/.cache"

# Windows Compatibility Environment Variables
export APPDATA="${CLAUSE_ROOT}/.local/appdata"
export LOCALAPPDATA="${CLAUSE_ROOT}/.local/share"

# Application Profile Targets
export GIT_CONFIG_GLOBAL="${CLAUSE_ROOT}/.gitconfig"
export NU_CONFIG_DIR="${CLAUSE_ROOT}/.config/nushell"
export GH_CONFIG_DIR="${CLAUSE_ROOT}/.config/gh"

# Isolated Toolchain Directories
export MISE_DATA_DIR="${CLAUSE_ROOT}/.cache/toolchain/mise"
export MISE_CONFIG_DIR="${CLAUSE_ROOT}/.cache/toolchain/mise-config"
export MISE_STATE_DIR="${CLAUSE_ROOT}/.cache/toolchain/mise-state"
export MISE_CACHE_DIR="${CLAUSE_ROOT}/.cache/toolchain/mise-cache"

# Enforce .local/bin Prepend
LOCAL_BIN="${CLAUSE_ROOT}/.local/bin"
case ":${PATH}:" in
    *:"${LOCAL_BIN}":*) ;;
    *) export PATH="${LOCAL_BIN}:${PATH}" ;;
esac