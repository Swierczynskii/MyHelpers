#!/usr/bin/env bash
set -euo pipefail

# install_all.sh: Execute all installation scripts in apps_installations for Fedora (dnf)

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Preconditions
if ! command -v bash >/dev/null 2>&1; then
  log "ERROR: bash is not available. This script requires bash."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  log "ERROR: sudo is not available. This script requires sudo for installations."
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  log "ERROR: dnf is not available. This script targets Fedora (dnf)."
  exit 1
fi

# Locate apps
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps_installations"

if [[ ! -d "$APPS_DIR" ]]; then
  log "ERROR: apps_installations directory not found at $APPS_DIR"
  exit 1
fi

log "Starting installation of all apps from $APPS_DIR"

# Initialize Flatpak/Flathub first if available (enables Flatpak fallbacks)
FLATPAK_BOOTSTRAP="$APPS_DIR/install_flatpak.sh"
if [[ -f "$FLATPAK_BOOTSTRAP" ]]; then
  log "Preparing Flatpak environment via $(basename "$FLATPAK_BOOTSTRAP")..."
  if bash "$FLATPAK_BOOTSTRAP"; then
    log "Flatpak environment prepared."
  else
    log "WARNING: Flatpak setup failed; continuing without Flatpak fallback."
  fi
fi

# Run tools_installations if present (idempotent scripts)
TOOLS_DIR="$SCRIPT_DIR/tools_installations"
if [[ -d "$TOOLS_DIR" ]]; then
  log "Starting tools installation from $TOOLS_DIR"
  TOOLS_SCRIPTS=("$TOOLS_DIR"/*.sh)
  if [[ ${#TOOLS_SCRIPTS[@]} -gt 0 && -f "${TOOLS_SCRIPTS[0]}" ]]; then
    for script in "${TOOLS_SCRIPTS[@]}"; do
      if [[ -f "$script" ]]; then
        script_name="$(basename "$script")"
        log "Processing $script_name..."
        if [[ ! -x "$script" ]]; then
          log "Making $script_name executable..."
          chmod +x "$script"
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
  else
    log "No tool installation scripts found in $TOOLS_DIR"
  fi
else
  log "tools_installations directory not found at $TOOLS_DIR (skipping tools)."
fi

INSTALL_SCRIPTS=("$APPS_DIR"/*.sh)

# Ensure there are scripts
if [[ ${#INSTALL_SCRIPTS[@]} -eq 0 ]] || [[ ! -f "${INSTALL_SCRIPTS[0]}" ]]; then
  log "ERROR: No installation scripts found in $APPS_DIR"
  exit 1
fi

# Execute each script in sequence
for script in "${INSTALL_SCRIPTS[@]}"; do
  if [[ -f "$script" ]]; then
    script_name="$(basename "$script")"
    # Skip the Flatpak bootstrap script (already executed above)
    if [[ "$script_name" == "install_flatpak.sh" ]]; then
      log "Skipping $script_name (already executed)."
      continue
    fi
    log "Processing $script_name..."

    # Make the script executable if necessary
    if [[ ! -x "$script" ]]; then
      log "Making $script_name executable..."
      chmod +x "$script"
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

log "All installation scripts have been executed successfully."
