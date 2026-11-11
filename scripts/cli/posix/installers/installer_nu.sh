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
TMP_DIR="${CLAUSE_TEMP_DIR:-${PROJECT_ROOT}/.home/.cache}"
NU_BIN="${LOCAL_BIN}/nu"

if [ -x "$NU_BIN" ]; then
    exit 0
fi

CLEAN_NU_VER="$(echo "$VERSION" | sed 's/^v//')"
write_clause_log "Seeding Nushell (v${CLEAN_NU_VER}) into $LOCAL_BIN..." "INFO"

ARCH="$(uname -m)"
IS_MAC=0
if [ "$(uname -s)" = "Darwin" ]; then
    IS_MAC=1
fi

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