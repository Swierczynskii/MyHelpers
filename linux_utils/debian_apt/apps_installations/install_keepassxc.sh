#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_keepassxc.sh
# Install KeePassXC via apt-get (distro repositories)
# Prerequisites: sudo, apt-get, network access
# Usage: ./install_keepassxc.sh
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
  title "Installing KeePassXC"
fi

# KeePassXC installation via apt (from official distro repositories)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Skip if already installed
log "Checking if KeePassXC is already installed..."
if dpkg -s keepassxc >/dev/null 2>&1 || command -v keepassxc >/dev/null 2>&1; then
  log "keepassxc already installed. Skipping."
  exit 0
fi

log "Updating package lists..."
sudo apt-get update

log "Installing KeePassXC..."
sudo apt-get install -y keepassxc

log "KeePassXC installation complete."
log "Launch: keepassxc"
