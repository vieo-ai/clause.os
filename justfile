# justfile
# ClauseOS Workbench — Internal Cockpit Task Runner
# Executes exclusively inside the active ClauseOS shell context.

# Set OS-specific shell interpreter
set windows-shell := ["powershell.exe", "-NoProfile", "-Command"]

# Default recipe: show help listing
default:
    @just --list

# Core launcher recipe
clause *args:
    @{{ if os() == "windows" { "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\clause.ps1" } else { "./clause.sh" } }} {{ args }}

# --- Common Shortcuts ---

# System verification check
check:
    just clause boot:check

# Subtree sync command
sync *args:
    just clause subtree:loom {{ args }}

# Manage background services
service *args:
    just clause service:manage {{ args }}

# Run container engine check
docker-check:
    clause docker:check

# Run the system-level assertion test suite
test:
    nu tests/system/run_all.nu