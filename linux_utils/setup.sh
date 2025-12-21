#!/usr/bin/env bash
set -euo pipefail

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

# Select backend based on available package manager
BACKEND=""
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

# 1) Run installers from the selected backend
INSTALL_ALL="$SCRIPT_DIR/$BACKEND/install_all.sh"
if [[ -x "$INSTALL_ALL" ]]; then
  log "Running installer bundle: $INSTALL_ALL"
  bash "$INSTALL_ALL"
elif [[ -f "$INSTALL_ALL" ]]; then
  log "Installer exists but is not executable; running with bash."
  bash "$INSTALL_ALL"
else
  log "Installer not found at $INSTALL_ALL (skipping app installations)."
fi

# 2) Copy upgrade helper from backend to $HOME (idempotent)
SRC_UPGRADE="$SCRIPT_DIR/$BACKEND/upgrade.sh"
DEST_UPGRADE="$HOME/upgrade.sh"
if [[ -f "$SRC_UPGRADE" ]]; then
  if [[ -e "$DEST_UPGRADE" ]]; then
    log "upgrade.sh already exists at $DEST_UPGRADE; leaving as-is."
  else
    log "Copying $SRC_UPGRADE to $DEST_UPGRADE"
    cp "$SRC_UPGRADE" "$DEST_UPGRADE"
    chmod +x "$DEST_UPGRADE" || true
  fi
else
  log "No upgrade.sh found at $SRC_UPGRADE."
fi

# 3) Set wallpaper from linux_utils/wallpaper (GNOME best-effort)
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