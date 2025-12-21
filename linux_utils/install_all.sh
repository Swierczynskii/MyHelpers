#!/usr/bin/env bash
set -euo pipefail

# Unified installer orchestrator for Debian/Ubuntu (apt) and Fedora (dnf)
# - Detects backend (or uses BACKEND env)
# - Runs backend/tools_installations/*.sh (if present)
# - Fedora: bootstraps Flatpak once via apps_installations/install_flatpak.sh if present
# - Runs backend/apps_installations/*.sh (skipping install_flatpak.sh if already executed)

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: Required command not found: $cmd"
    exit 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Preconditions
require_cmd bash
if ! command -v sudo >/dev/null 2>&1; then
  log "ERROR: sudo is not available. Installers typically require privilege escalation."
  exit 1
fi

# Backend detection (prefer env BACKEND from setup.sh)
BACKEND="${BACKEND:-}"
if [[ -z "$BACKEND" ]]; then
  if command -v apt >/dev/null 2>&1; then
    BACKEND="debian_apt"
    log "Detected Debian/Ubuntu (apt) environment."
  elif command -v dnf >/dev/null 2>&1; then
    BACKEND="fedora_dnf"
    log "Detected Fedora (dnf) environment."
  else
    log "Unsupported Linux distribution: neither apt nor dnf found."
    exit 1
  fi
else
  log "Using preselected backend: $BACKEND"
fi

APPS_DIR="$SCRIPT_DIR/$BACKEND/apps_installations"
TOOLS_DIR="$SCRIPT_DIR/$BACKEND/tools_installations"

if [[ ! -d "$APPS_DIR" ]]; then
  log "ERROR: apps_installations directory not found at $APPS_DIR"
  exit 1
fi

log "Starting installation orchestrator for backend: $BACKEND"
log "Apps directory: $APPS_DIR"

# 1) Run tools_installations (idempotent, if present)
if [[ -d "$TOOLS_DIR" ]]; then
  log "Processing tools from: $TOOLS_DIR"
  shopt -s nullglob
  TOOLS_SCRIPTS=("$TOOLS_DIR"/*.sh)
  if [[ ${#TOOLS_SCRIPTS[@]} -gt 0 ]]; then
    for tool_script in "${TOOLS_SCRIPTS[@]}"; do
      if [[ -f "$tool_script" ]]; then
        tool_name="$(basename "$tool_script")"
        log "Processing $tool_name..."
        if [[ ! -x "$tool_script" ]]; then
          chmod +x "$tool_script" || true
        fi
        if bash "$tool_script"; then
          log "Successfully executed $tool_name"
        else
          log "ERROR: Failed to execute $tool_name. Stopping execution."
          exit 1
        fi
      fi
    done
  else
    log "No scripts found in $TOOLS_DIR"
  fi
  shopt -u nullglob
else
  log "No tools_installations directory at $TOOLS_DIR (skipping tools)."
fi

# 2) Fedora-only: Flatpak bootstrap (if present)
SKIP_FILE=""
if [[ "$BACKEND" == "fedora_dnf" ]]; then
  FLATPAK_BOOTSTRAP="$APPS_DIR/install_flatpak.sh"
  if [[ -f "$FLATPAK_BOOTSTRAP" ]]; then
    log "Preparing Flatpak environment via $(basename "$FLATPAK_BOOTSTRAP")..."
    if [[ ! -x "$FLATPAK_BOOTSTRAP" ]]; then
      chmod +x "$FLATPAK_BOOTSTRAP" || true
    fi
    if bash "$FLATPAK_BOOTSTRAP"; then
      log "Flatpak environment prepared."
      SKIP_FILE="$(basename "$FLATPAK_BOOTSTRAP")"
    else
      log "WARNING: Flatpak setup failed; continuing without Flatpak fallback."
    fi
  fi
fi

# 3) Run app installers
shopt -s nullglob
INSTALL_SCRIPTS=("$APPS_DIR"/*.sh)
if [[ ${#INSTALL_SCRIPTS[@]} -eq 0 ]]; then
  log "ERROR: No installation scripts found in $APPS_DIR"
  exit 1
fi

for script in "${INSTALL_SCRIPTS[@]}"; do
  if [[ -f "$script" ]]; then
    script_name="$(basename "$script")"
    # Skip the bootstrap script if already executed
    if [[ -n "$SKIP_FILE" && "$script_name" == "$SKIP_FILE" ]]; then
      log "Skipping $script_name (already executed)."
      continue
    fi
    log "Processing $script_name..."
    if [[ ! -x "$script" ]]; then
      chmod +x "$script" || true
    fi
    log "Executing $script_name..."
    if bash "$script"; then
      log "Successfully executed $script_name"
    else
      log "ERROR: Failed to execute $script_name. Stopping execution."
      exit 1
    fi
  fi
done
shopt -u nullglob

log "All installation scripts have been executed successfully."