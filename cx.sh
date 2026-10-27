#!/bin/sh
# cx.sh - Reads .clause.toml, bootstraps pwsh into .home/.local/bin, and hands off to boot.ps1
set -e

PROJECT_ROOT="${CLAUSE_PROJECT_ROOT:-$(cd "$(dirname "$0")" && pwd -P)}"
export CLAUSE_PROJECT_ROOT="$PROJECT_ROOT"

LOCAL_BIN="$PROJECT_ROOT/.home/.local/bin"
CACHE_DIR="$PROJECT_ROOT/.home/.cache"
TMP_DIR="$CACHE_DIR/tmp_bootstrap"
MANIFEST="$PROJECT_ROOT/.clause.toml"
PWSH_EXE="$LOCAL_BIN/pwsh"

mkdir -p "$LOCAL_BIN" "$TMP_DIR"

if [ ! -f "$PWSH_EXE" ]; then
    if [ ! -f "$MANIFEST" ]; then
        echo "[ClauseOS] Error: Manifest file not found at $MANIFEST"
        exit 1
    fi

    PWSH_VER=$(sed -n 's/^[[:space:]]*pwsh[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -n 1)
    if [ -z "$PWSH_VER" ]; then
        echo "[ClauseOS] Error: Could not parse 'pwsh' version from .clause.toml"
        exit 1
    fi

    PWSH_VER=$(echo "$PWSH_VER" | sed 's/^v//')

    echo "[ClauseOS] Seeding PowerShell Core (v${PWSH_VER}) into .home/.local/bin/..."
    
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64) PWSH_ASSET="powershell-${PWSH_VER}-linux-x64.tar.gz" ;;
                aarch64) PWSH_ASSET="powershell-${PWSH_VER}-linux-arm64.tar.gz" ;;
                *) echo "[ClauseOS] Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            ;;
        Darwin)
            case "$ARCH" in
                x86_64|arm64) PWSH_ASSET="powershell-${PWSH_VER}-osx-x64.tar.gz" ;;
                *) echo "[ClauseOS] Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            ;;
        *)
            echo "[ClauseOS] Unsupported POSIX OS: $OS"; exit 1 ;;
    esac

    URL="https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VER}/$PWSH_ASSET"
    DEST="$TMP_DIR/$PWSH_ASSET"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$URL" -o "$DEST"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$DEST" "$URL"
    else
        echo "[ClauseOS] Error: Neither curl nor wget is available."
        exit 1
    fi

    PWSH_EXTRACT="$TMP_DIR/pwsh_extract"
    mkdir -p "$PWSH_EXTRACT"
    tar -xzf "$DEST" -C "$PWSH_EXTRACT"
    
    cp -R "$PWSH_EXTRACT"/* "$LOCAL_BIN/"
    chmod +x "$PWSH_EXE"
    rm -rf "$TMP_DIR"
fi

exec "$PWSH_EXE" -NoProfile -ExecutionPolicy Bypass -File "$PROJECT_ROOT/boot.ps1" "$@"