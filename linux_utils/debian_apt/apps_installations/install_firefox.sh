#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_firefox.sh
# Install Firefox via official Mozilla APT repository (keyrings + signed-by)
# Prerequisites: sudo, apt-get, curl or wget, network access, optional snap
# Usage: ./install_firefox.sh
# Non-interactive: export DEBIAN_FRONTEND=noninteractive
# -----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
fi

TIMESTAMP_COLOR='\033[1;36m'
TITLE_COLOR='\033[1;33m'
ERROR_COLOR='\033[1;31m'
NC='\033[0m'

timestamp() {
  local ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
  if (( COLOR_ENABLED )); then
    printf '%b%s%b' "$TIMESTAMP_COLOR" "$ts" "$NC"
  else
    printf '%s' "$ts"
  fi
}

log() {
  printf '%s %s\n' "$(timestamp)" "$*"
}

err() {
  if (( COLOR_ENABLED )); then
    printf '%s %bERROR:%b %s\n' "$(timestamp)" "$ERROR_COLOR" "$NC" "$*" >&2
  else
    printf '%s ERROR: %s\n' "$(timestamp)" "$*" >&2
  fi
}

title() {
  if (( COLOR_ENABLED )); then
    printf '%s %b%s%b\n' "$(timestamp)" "$TITLE_COLOR" "$*" "$NC"
  else
    printf '%s %s\n' "$(timestamp)" "$*"
  fi
}

if [[ "${SKIP_INSTALLER_TITLE:-0}" != "1" ]]; then
  title "Installing Firefox"
fi

# Firefox installation via official Mozilla APT repository (keyrings + signed-by)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

log "Ensuring prerequisites..."
NEED_UPDATE=0
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  log "Installing wget (no curl/wget found)"
  sudo apt-get update
  sudo apt-get install -y wget
  NEED_UPDATE=1
fi

# Special handling for Firefox:
# - If Snap Firefox exists, remove it first
# - If APT Firefox already installed, skip installation
log "Checking for Snap Firefox..."
if command -v snap >/dev/null 2>&1; then
  if snap list firefox >/dev/null 2>&1; then
    log "Found Firefox installed via Snap. Removing..."
    if ! sudo snap remove --purge firefox; then
      log "Purge failed; attempting regular remove..."
      sudo snap remove firefox || { err "Unable to remove Snap Firefox."; exit 1; }
    fi
    log "Removed Snap Firefox."
  else
    log "Snap Firefox not present."
  fi
else
  log "snap not found; skipping snap check."
fi

log "Checking if Firefox (APT) is already installed..."
if dpkg -s firefox >/dev/null 2>&1; then
  log "Firefox (APT) already installed. Skipping."
  exit 0
fi

log "Preparing keyrings directory..."
sudo install -d -m 0755 /etc/apt/keyrings

KEYRING="/etc/apt/keyrings/packages.mozilla.org.asc"
LIST="/etc/apt/sources.list.d/mozilla.list"
PREF="/etc/apt/preferences.d/mozilla"

log "Installing Mozilla signing key..."
if [[ ! -f "$KEYRING" ]]; then
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo tee "$KEYRING" >/dev/null
  else
    wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo tee "$KEYRING" >/dev/null
  fi
  sudo chmod 0644 "$KEYRING"
else
  log "Keyring already exists: $KEYRING"
fi

log "Adding Mozilla APT repository..."
if [[ ! -f "$LIST" ]]; then
  echo "deb [signed-by=$KEYRING] https://packages.mozilla.org/apt mozilla main" | sudo tee "$LIST" >/dev/null
else
  log "Repository list already exists: $LIST"
fi

log "Setting APT pinning to prefer Mozilla origin..."
if [[ ! -f "$PREF" ]]; then
  sudo tee "$PREF" >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
else
  log "Preferences already exist: $PREF"
fi

log "Updating package lists..."
sudo apt-get update

log "Installing firefox..."
sudo apt-get install -y firefox

log "Firefox installation complete."
log "Launch: firefox"
