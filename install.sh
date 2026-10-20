#!/bin/sh
# install.sh - Bootstraps pwsh into .local/bin and hands off directly to clause.ps1
set -e

PROJECT_ROOT="${CLAUSE_PROJECT_ROOT:-$(cd "$(dirname "$0")" && pwd -P)}"
export CLAUSE_PROJECT_ROOT="$PROJECT_ROOT"

LOCAL_BIN="$PROJECT_ROOT/.local/bin"
CACHE_DIR="$PROJECT_ROOT/.cache"
TMP_DIR="$CACHE_DIR/tmp_bootstrap"
PWSH_EXE="$LOCAL_BIN/pwsh"

mkdir -p "$LOCAL_BIN" "$TMP_DIR"

if [ ! -f "$PWSH_EXE" ]; then
    echo "[ClauseOS] Seeding PowerShell Core into .local/bin/..."
    
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64) PWSH_ASSET="powershell-7.4.1-linux-x64.tar.gz" ;;
                aarch64) PWSH_ASSET="powershell-7.4.1-linux-arm64.tar.gz" ;;
                *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            ;;
        Darwin)
            case "$ARCH" in
                x86_64|arm64) PWSH_ASSET="powershell-7.4.1-osx-x64.tar.gz" ;;
                *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            ;;
        *)
            echo "Unsupported POSIX OS: $OS"; exit 1 ;;
    esac

    URL="https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/$PWSH_ASSET"
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

exec "$PWSH_EXE" -NoProfile -ExecutionPolicy Bypass -File "$PROJECT_ROOT/clause.ps1" "$@"