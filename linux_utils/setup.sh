#!/usr/bin/env bash
set -euo pipefail
# -----------------------------------------------------------------------------
# linux_utils/setup.sh
# Orchestrated Linux setup for Debian/Ubuntu (apt).
# - Bootstraps developer toolchains (Node.js + Corepack/pnpm, uv)
# - Runs per-backend app installers via install_all.sh
# - Ensures lm-sensors and copies monitor.sh to $HOME
# - Copies backend-specific upgrade.sh to $HOME
# - Best-effort GNOME wallpaper configuration with interactive picture-options
# Safe to re-run; individual steps are idempotent.
# -----------------------------------------------------------------------------

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
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

# Select backend based on available package manager (apt-only)
BACKEND="debian_apt"
if command -v apt >/dev/null 2>&1; then
  log "Detected Debian/Ubuntu (apt) environment."
else
  log "Unsupported Linux distribution: apt not found."
  exit 1
fi

# 1) Bootstrap developer toolchains (Node.js + Corepack/pnpm, uv)
TOOLCHAIN_BOOTSTRAP="$SCRIPT_DIR/toolchains/bootstrap_toolchains.sh"
if [[ -f "$TOOLCHAIN_BOOTSTRAP" ]]; then
  log "Bootstrapping developer toolchains via $TOOLCHAIN_BOOTSTRAP"
  BACKEND="$BACKEND" bash "$TOOLCHAIN_BOOTSTRAP"
else
  log "Toolchain bootstrap script not found at $TOOLCHAIN_BOOTSTRAP (skipping)."
fi

# 2) Run unified installer orchestrator
INSTALL_ALL="$SCRIPT_DIR/install_all.sh"
if [[ -x "$INSTALL_ALL" ]]; then
  log "Running installer bundle: $INSTALL_ALL"
  BACKEND="$BACKEND" bash "$INSTALL_ALL"
elif [[ -f "$INSTALL_ALL" ]]; then
  log "Installer exists but is not executable; running with bash."
  BACKEND="$BACKEND" bash "$INSTALL_ALL"
else
  log "Installer not found at $INSTALL_ALL (skipping app installations)."
fi

# 2a) Ensure lm-sensors is installed for temperature monitoring (apt-only)
if ! dpkg -s lm-sensors >/dev/null 2>&1; then
  log "Installing lm-sensors (apt)..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y || true
    sudo apt-get install -y lm-sensors
  else
    sudo apt update -y || true
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

# 4) Set wallpaper from linux_utils/wallpaper (GNOME best-effort)
WALLPAPER_DIR="$SCRIPT_DIR/wallpaper"
if command -v gsettings >/dev/null 2>&1; then
  if gsettings list-schemas | grep -q '^org.gnome.desktop.background$'; then
    if [[ -d "$WALLPAPER_DIR" ]]; then
      WALLPAPER_FILE="$(
        find "$WALLPAPER_DIR" -maxdepth 1 -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.webp' \) \
          | head -n 1
      )"
      if [[ -n "${WALLPAPER_FILE:-}" ]]; then
        log "Setting GNOME wallpaper to: $WALLPAPER_FILE"
        URI="file://$WALLPAPER_FILE"

        # Prompt for GNOME wallpaper mode at runtime
        VALID_OPTS=("none" "wallpaper" "centered" "scaled" "stretched" "zoom" "spanned")
        DEFAULT_OPT="zoom"

        echo "Select GNOME wallpaper mode:"
        for i in "${!VALID_OPTS[@]}"; do
          printf "  [%d] %s%s\n" "$((i+1))" "${VALID_OPTS[$i]}" "$( [[ ${VALID_OPTS[$i]} == "$DEFAULT_OPT" ]] && echo " (default)" )"
        done
        read -r -p "Enter number or name [default: ${DEFAULT_OPT}]: " USER_CHOICE || true

        CHOSEN_OPT="$DEFAULT_OPT"
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

        gsettings set org.gnome.desktop.background picture-uri "$URI" || true
        gsettings set org.gnome.desktop.background picture-uri-dark "$URI" || true
        gsettings set org.gnome.desktop.background picture-options "$CHOSEN_OPT" || true
      else
        log "No supported image files found in $WALLPAPER_DIR. Skipping wallpaper."
      fi
    else
      log "No wallpaper directory at $WALLPAPER_DIR. Skipping wallpaper."
    fi
  else
    log "GNOME background schema not found; skipping wallpaper."
  fi
else
  log "gsettings not found; skipping wallpaper (non-GNOME environment)."
fi

log "Setup completed successfully for ${OS_NAME:-Linux} using backend '$BACKEND'."