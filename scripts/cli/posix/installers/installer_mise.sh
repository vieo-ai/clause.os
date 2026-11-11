#!/usr/bin/env bash
set -euo pipefail

VERSION=""
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        --project-root|-p)
            PROJECT_ROOT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    echo "[ClauseOS] FATAL: Missing --version argument" >&2
    exit 1
fi

# ==============================================================================
# FALLBACK LOGGER (Right here: before any calls to write_clause_log)
# ==============================================================================
if ! command -v write_clause_log >/dev/null 2>&1; then
    write_clause_log() {
        echo "[ClauseOS ${2:-INFO}] $1"
    }
fi

LOCAL_BIN="${CLAUSE_BIN_DIR:-${PROJECT_ROOT}/.home/.local/bin}"
MISE_BIN="${LOCAL_BIN}/mise"

# Fast-path check: use return instead of exit
if [ -x "$MISE_BIN" ]; then
    return 0 2>/dev/null || exit 0
fi

CLEAN_MISE_VER="$(echo "$VERSION" | sed 's/^v//')"
write_clause_log "Seeding Mise (v${CLEAN_MISE_VER}) into $LOCAL_BIN..." "INFO"

ARCH="$(uname -m)"
IS_MAC=0
if [ "$(uname -s)" = "Darwin" ]; then
    IS_MAC=1
fi

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