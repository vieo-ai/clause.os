#!/usr/bin/env bash
set -euo pipefail

# Accept from parent environment or parse positional flags
VERSION="${VERSION:-}"
PROJECT_ROOT="${PROJECT_ROOT:-}"

while [ $# -gt 0 ]; do
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
    echo "[ClauseOS] FATAL: Missing --version argument for Homebrew" >&2
    return 1 2>/dev/null || exit 1
fi

LOCAL_BIN="${CLAUSE_BIN_DIR:-${PROJECT_ROOT}/.home/.local/bin}"
CACHE_DIR="${CLAUSE_CACHE_DIR:-${PROJECT_ROOT}/.home/.cache}"
TOOLCHAIN_DIR="${CACHE_DIR}/toolchain"
BREW_DIR="${TOOLCHAIN_DIR}/brew"
BREW_BIN_DIR="${BREW_DIR}/bin"
BREW_EXE="${BREW_BIN_DIR}/brew"

# Fast-path exit if already seeded
if [ -x "$BREW_EXE" ]; then
    return 0 2>/dev/null || exit 0
fi

if ! command -v write_clause_log >/dev/null 2>&1; then
    write_clause_log() {
        echo "[ClauseOS ${2:-INFO}] $1"
    }
fi

write_clause_log "Pre-seeding Hermetic Homebrew ($VERSION) into ${BREW_DIR}..." "INFO"
mkdir -p "$BREW_DIR"

BREW_REF="${VERSION:-main}"
BREW_TARBALL_URL="https://github.com/Homebrew/brew/tarball/${BREW_REF}"

if command -v curl >/dev/null 2>&1; then
    curl -sSL "$BREW_TARBALL_URL" | tar xz --strip-components 1 -C "$BREW_DIR"
elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$BREW_TARBALL_URL" | tar xz --strip-components 1 -C "$BREW_DIR"
else
    write_clause_log "Neither curl nor wget is available for Homebrew seeding." "FATAL"
    return 1 2>/dev/null || exit 1
fi

chmod +x "$BREW_EXE" 2>/dev/null || true

# Symlink or wrap brew binary into CLAUSE_BIN_DIR so Mise can locate it on PATH
mkdir -p "$LOCAL_BIN"
ln -sf "$BREW_EXE" "${LOCAL_BIN}/brew"

write_clause_log "Hermetic Homebrew pre-seeded successfully." "INFO"