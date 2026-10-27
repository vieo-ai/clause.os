#!/usr/bin/env sh
set -e

pass() { printf "\033[32m [PASS] %s\033[0m\n" "$1"; }
fail() { printf "\033[31m [FAIL] %s\033[0m\n" "$1"; exit 1; }

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
ENV_SCRIPT="$PROJECT_ROOT/scripts/cli/sh/config/env.sh"[cite: 14, 19]
EXPECTED_HOME="$PROJECT_ROOT/.home"[cite: 5, 19]

sh -c '
    . "'"$ENV_SCRIPT"'"[cite: 43, 45]

    [ "$HOME" = "'"$EXPECTED_HOME"'" ] || exit 1[cite: 5, 19]
    [ "$USERPROFILE" = "'"$EXPECTED_HOME"'" ] || exit 2[cite: 5, 19]
    [ "$XDG_CONFIG_HOME" = "'"$EXPECTED_HOME/.config"'" ] || exit 3[cite: 5, 19]
    [ "$XDG_CACHE_HOME" = "'"$EXPECTED_HOME/.cache"'" ] || exit 4[cite: 5, 19]

    case "$PATH" in
        *"mise/shims"*) exit 5 ;;[cite: 30, 32]
        "$CLAUSE_BIN_DIR":*) ;;[cite: 20, 32]
        *) exit 6 ;;
    esac
'

STATUS=$?
case $STATUS in
    0) pass "All env.sh assertions passed" ;;
    1) fail "HOME does not point to .home" ;;
    2) fail "USERPROFILE does not point to .home" ;;
    3) fail "XDG_CONFIG_HOME does not point to .home/.config" ;;
    4) fail "XDG_CACHE_HOME does not point to .home/.cache" ;;
    5) fail "PATH includes unwanted Mise shims" ;;
    6) fail "CLAUSE_BIN_DIR is not prepended to PATH" ;;
    *) fail "Unknown failure (code $STATUS)" ;;
esac