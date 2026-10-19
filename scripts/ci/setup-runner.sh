#!/bin/sh
# scripts/ci/setup-runner.sh
# Persistent Self-Hosted Runner Provisioner for POSIX
set -e

REPO_URL="$1"
RUNNER_TOKEN="$2"

PROJECT_ROOT="${CLAUSE_PROJECT_ROOT:-$(pwd -P 2>/dev/null || pwd)}"
RUNNER_DIR="$PROJECT_ROOT/.cache/ci/runner"
TMP_DIR="$PROJECT_ROOT/.cache/tmp_bootstrap"

mkdir -p "$RUNNER_DIR" "$TMP_DIR"

OS="$(uname -s)"
RUNNER_VER="2.337.0"

case "$OS" in
    Linux)
        RUNNER_ASSET="actions-runner-linux-x64-${RUNNER_VER}.tar.gz"
        ;;
    Darwin)
        ARCH="$(uname -m)"
        if [ "$ARCH" = "arm64" ]; then
            RUNNER_ASSET="actions-runner-osx-arm64-${RUNNER_VER}.tar.gz"
        else
            RUNNER_ASSET="actions-runner-osx-x64-${RUNNER_VER}.tar.gz"
        fi
        ;;
    *)
        echo "[ClauseOS CI] Unsupported OS: $OS"
        exit 1
        ;;
esac

RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VER}/${RUNNER_ASSET}"
TAR_PATH="$TMP_DIR/$RUNNER_ASSET"

if [ ! -f "$RUNNER_DIR/config.sh" ]; then
    echo "[ClauseOS CI] Downloading GitHub Actions Runner (v${RUNNER_VER})..."
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$RUNNER_URL" -o "$TAR_PATH"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$TAR_PATH" "$RUNNER_URL"
    fi

    echo "[ClauseOS CI] Extracting runner into .cache/ci/runner..."
    tar -xzf "$TAR_PATH" -C "$RUNNER_DIR"
fi

cd "$RUNNER_DIR"

if [ ! -f "$RUNNER_DIR/.runner" ]; then
    if [ -z "$REPO_URL" ]; then
        printf "Enter GitHub Repository URL: "
        read -r REPO_URL
    fi
    if [ -z "$RUNNER_TOKEN" ]; then
        printf "Enter GitHub Runner Registration Token: "
        read -r RUNNER_TOKEN
    fi

    echo "[ClauseOS CI] Registering runner agent with GitHub..."
    ./config.sh --url "$REPO_URL" --token "$RUNNER_TOKEN" --labels linux,x64 --unattended --replace
else
    echo "[ClauseOS CI] Existing registration found. Reconnecting to GitHub..."
fi

echo "[ClauseOS CI] Runner listening for jobs. Press Ctrl+C to stop..."
./run.sh