#!/usr/bin/env sh
# scripts/cli/sh/config/env.sh - ClauseOS POSIX Shell Subshell Lock

if [ -z "$CLAUSE_PROJECT_ROOT" ]; then
    CLAUSE_ROOT="$(cd "$(dirname "${ALIAS_SOURCE:-$0}")/../../../.." && pwd -P)"
    export CLAUSE_PROJECT_ROOT="$CLAUSE_ROOT"
else
    CLAUSE_ROOT="$CLAUSE_PROJECT_ROOT"
fi

export CLAUSE_HOME="${CLAUSE_ROOT}/.home"
export HOME="$CLAUSE_HOME"
export USERPROFILE="$CLAUSE_HOME"

# XDG Base Directories inside .home
export XDG_CONFIG_HOME="${CLAUSE_HOME}/.config"
export XDG_DATA_HOME="${CLAUSE_HOME}/.local/share"
export XDG_STATE_HOME="${CLAUSE_HOME}/.local/state"
export XDG_CACHE_HOME="${CLAUSE_HOME}/.cache"

export CLAUSE_BIN_DIR="${CLAUSE_HOME}/.local/bin"
export CLAUSE_APPS_DIR="${CLAUSE_HOME}/.local/apps"
export CLAUSE_TEMP_DIR="${XDG_CACHE_HOME}/tmp_bootstrap"
export CLAUSE_LOGS_DIR="${CLAUSE_HOME}/.local/logs"

# Application Profile Targets
export GIT_CONFIG_GLOBAL="${CLAUSE_HOME}/.gitconfig"
export GH_CONFIG_DIR="${XDG_CONFIG_HOME}/gh"
export NU_CONFIG_DIR="${CLAUSE_ROOT}/scripts/cli/nu/config"

# Isolated Toolchain Directories
export MISE_DATA_DIR="${XDG_DATA_HOME}/mise"
export MISE_CONFIG_DIR="${XDG_CONFIG_HOME}/mise"
export MISE_STATE_DIR="${XDG_STATE_HOME}/mise"
export MISE_CACHE_DIR="${XDG_CACHE_HOME}/mise"

# Enforce CLAUSE_BIN_DIR Prepend Only
case ":${PATH}:" in
    *:"${CLAUSE_BIN_DIR}":*) ;;
    *) export PATH="${CLAUSE_BIN_DIR}:${PATH}" ;;
esac