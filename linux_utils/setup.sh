#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/setup.sh
# Orchestrated Linux setup for Debian/Ubuntu (apt).
# - Bootstraps developer toolchains (Node.js + Corepack/pnpm, uv)
# - Runs per-backend tool/app installers inline (apt-only backend allowlist)
# - Ensures lm-sensors and copies monitor.sh to $HOME
# - Copies backend-specific upgrade.sh to $HOME
# - Best-effort GNOME wallpaper configuration via gsettings; interactive picture-options are TTY-only
# Safe to re-run; individual steps are idempotent.
# -----------------------------------------------------------------------------

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

validate_backend() {
  local backend="$1"
  case "$backend" in
    debian_apt) return 0 ;;
    *)
      log "ERROR: Invalid BACKEND '$backend'. Allowed: debian_apt"
      exit 1
      ;;
  esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS pretty name for final message
OS_ID=""
OS_NAME=""
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_NAME="${PRETTY_NAME:-${NAME:-$OS_ID}}"
fi

# Preconditions
require_cmd bash
if ! command -v sudo >/dev/null 2>&1; then
  log "ERROR: sudo is not available. Installers typically require privilege escalation."
  exit 1
fi

# Backend detection and validation
BACKEND="${BACKEND:-}"
if [[ -z "$BACKEND" ]]; then
  if command -v apt >/dev/null 2>&1; then
    BACKEND="debian_apt"
    log "Detected Debian/Ubuntu (apt) environment."
  else
    log "Unsupported Linux distribution: apt not found."
    exit 1
  fi
else
  log "Using preselected backend: $BACKEND"
fi
validate_backend "$BACKEND"

# 1) Bootstrap developer toolchains (Node.js + Corepack/pnpm, uv)
TOOLCHAIN_BOOTSTRAP="$SCRIPT_DIR/toolchains/bootstrap_toolchains.sh"
if [[ -f "$TOOLCHAIN_BOOTSTRAP" ]]; then
  log "Bootstrapping developer toolchains via $TOOLCHAIN_BOOTSTRAP"
  BACKEND="$BACKEND" bash "$TOOLCHAIN_BOOTSTRAP"
else
  log "Toolchain bootstrap script not found at $TOOLCHAIN_BOOTSTRAP (skipping)."
fi

# 2) Run unified installer orchestrator (inline)
APPS_DIR="$SCRIPT_DIR/$BACKEND/apps_installations"
TOOLS_DIR="$SCRIPT_DIR/$BACKEND/tools_installations"

if [[ ! -d "$APPS_DIR" ]]; then
  log "ERROR: apps_installations directory not found at $APPS_DIR"
  exit 1
fi

log "Starting installation orchestrator for backend: $BACKEND"
log "Apps directory: $APPS_DIR"

# Tools phase
if [[ -d "$TOOLS_DIR" ]]; then
  log "Processing tools from: $TOOLS_DIR"
  shopt -s nullglob
  TOOLS_SCRIPTS=("$TOOLS_DIR"/install_*.sh)
  if [[ ${#TOOLS_SCRIPTS[@]} -gt 0 ]]; then
    for tool_script in "${TOOLS_SCRIPTS[@]}"; do
      if [[ -f "$tool_script" ]]; then
        tool_name="$(basename "$tool_script")"
        log "Processing $tool_name..."
        if [[ ! -x "$tool_script" ]]; then
          log "ERROR: $tool_name is not executable; refusing to change permissions automatically."
          exit 1
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
    log "No scripts found in $TOOLS_DIR (pattern: install_*.sh)"
  fi
  shopt -u nullglob
else
  log "No tools_installations directory at $TOOLS_DIR (skipping tools)."
fi

# Apps phase
shopt -s nullglob
INSTALL_SCRIPTS=("$APPS_DIR"/install_*.sh)
if [[ ${#INSTALL_SCRIPTS[@]} -eq 0 ]]; then
  log "ERROR: No installation scripts found in $APPS_DIR (pattern: install_*.sh)"
  exit 1
fi

for script in "${INSTALL_SCRIPTS[@]}"; do
  if [[ -f "$script" ]]; then
    script_name="$(basename "$script")"
    log "Processing $script_name..."
    if [[ ! -x "$script" ]]; then
      log "ERROR: $script_name is not executable; refusing to change permissions automatically."
      exit 1
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

# 2a) Ensure lm-sensors is installed for temperature monitoring (apt-only)
if ! dpkg -s lm-sensors >/dev/null 2>&1; then
  log "Installing lm-sensors (apt)..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update || true
    sudo apt-get install -y lm-sensors
  else
    sudo apt update || true
    sudo apt install -y lm-sensors
  fi
else
  log "lm-sensors already installed."
fi

# 3) Copy upgrade helper from backend to $HOME (force overwrite, ensure executable)
SRC_UPGRADE="$SCRIPT_DIR/$BACKEND/upgrade.sh"
DEST_UPGRADE="$HOME/upgrade.sh"
if [[ -f "$SRC_UPGRADE" ]]; then
  log "Copying $SRC_UPGRADE to $DEST_UPGRADE (overwriting)"
  cp -f "$SRC_UPGRADE" "$DEST_UPGRADE"
  chmod +x "$DEST_UPGRADE" || true
else
  log "No upgrade.sh found at $SRC_UPGRADE."
fi

# 3a) Copy monitor.sh helper to $HOME (force overwrite) and ensure executable
SRC_MONITOR="$SCRIPT_DIR/monitor.sh"
DEST_MONITOR="$HOME/monitor.sh"
if [[ -f "$SRC_MONITOR" ]]; then
  log "Copying $SRC_MONITOR to $DEST_MONITOR (overwriting)"
  cp -f "$SRC_MONITOR" "$DEST_MONITOR"
  chmod +x "$DEST_MONITOR" || true
else
  log "No monitor.sh found at $SRC_MONITOR."
fi

# 4) Set wallpaper from linux_utils/wallpaper (GNOME only; uses gsettings; only .jpeg/.jpg/.png; placeholder handling)
WALLPAPER_DIR="$SCRIPT_DIR/wallpaper"

# Verify GNOME environment
if ! command -v gsettings >/dev/null 2>&1; then
  log "Skipped wallpaper: GNOME environment required (gsettings not found)."
else
  if ! gsettings list-schemas | grep -q '^org.gnome.desktop.background$'; then
    log "Skipped wallpaper: org.gnome.desktop.background schema missing (requires GNOME)."
  else
    DESKTOP_LC="$(printf '%s %s' "${XDG_CURRENT_DESKTOP:-}" "${DESKTOP_SESSION:-}" | tr '[:upper:]' '[:lower:]')"
    if [[ "$DESKTOP_LC" != *gnome* ]]; then
      log "Skipped wallpaper: detected non-GNOME desktop (${XDG_CURRENT_DESKTOP:-}${DESKTOP_SESSION:+, $DESKTOP_SESSION})."
    else
      if [[ -d "$WALLPAPER_DIR" ]]; then
        # Search only .jpeg/.jpg/.png
        WALLPAPER_FILE="$(
          find "$WALLPAPER_DIR" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
            | head -n 1
        )"

        if [[ -z "${WALLPAPER_FILE:-}" ]]; then
          if [[ -f "$WALLPAPER_DIR/placeholder" ]]; then
            log "Only 'placeholder' found in $WALLPAPER_DIR. No .jpeg/.jpg/.png image to set as wallpaper. Add an image with extension .jpeg, .jpg or .png."
          else
            log "No supported images (.jpeg/.jpg/.png) in $WALLPAPER_DIR. Skipping wallpaper."
          fi
        else
          # Additional extension check (must be .jpeg/.jpg/.png)
          case "${WALLPAPER_FILE,,}" in
            *.jpg|*.jpeg|*.png) ;;
            *)
              log "Skipped wallpaper: found file is not .jpeg/.jpg/.png: $WALLPAPER_FILE"
              WALLPAPER_FILE=""
              ;;
          esac

          if [[ -n "$WALLPAPER_FILE" ]]; then
            log "Setting GNOME wallpaper: $WALLPAPER_FILE"
            URI="file://$WALLPAPER_FILE"

            # Interactive selection of GNOME wallpaper picture-options
            VALID_OPTS=("none" "wallpaper" "centered" "scaled" "stretched" "zoom" "spanned")
            DEFAULT_OPT="zoom"

            CHOSEN_OPT="$DEFAULT_OPT"
            if [[ -t 0 ]]; then
              echo "Select GNOME wallpaper mode:"
              for i in "${!VALID_OPTS[@]}"; do
                printf "  [%d] %s%s\n" "$((i+1))" "${VALID_OPTS[$i]}" "$( [[ ${VALID_OPTS[$i]} == "$DEFAULT_OPT" ]] && echo " (default)" )"
              done
              read -r -p "Enter number or name [default: ${DEFAULT_OPT}]: " USER_CHOICE || true

              if [[ -n "${USER_CHOICE:-}" ]]; then
                if [[ "$USER_CHOICE" =~ ^[0-9]+$ ]]; then
                  idx=$((USER_CHOICE-1))
                  if (( idx >= 0 && idx < ${#VALID_OPTS[@]} )); then
                    CHOSEN_OPT="${VALID_OPTS[$idx]}"
                  fi
                else
                  for opt in "${VALID_OPTS[@]}"; do
                    if [[ "$opt" == "$USER_CHOICE" ]]; then
                      CHOSEN_OPT="$opt"
                      break
                    fi
                  done
                fi
              fi
            else
              log "Non-interactive stdin detected; using default wallpaper picture-options: ${DEFAULT_OPT}"
            fi

            gsettings set org.gnome.desktop.background picture-uri "$URI" || true
            gsettings set org.gnome.desktop.background picture-uri-dark "$URI" || true
            gsettings set org.gnome.desktop.background picture-options "$CHOSEN_OPT" || true
          fi
        fi
      else
        log "No wallpaper directory at $WALLPAPER_DIR. Skipping wallpaper."
      fi
    fi
  fi
fi

log "Setup completed successfully for ${OS_NAME:-Linux} using backend '$BACKEND'."