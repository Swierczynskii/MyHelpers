#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_virtualbox.sh
# Install VirtualBox via apt-get (distro repositories)
# Prerequisites: sudo, apt-get, network access
# Usage: ./install_virtualbox.sh
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
  title "Installing VirtualBox"
fi

# VirtualBox installation via apt (from distro repositories)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

log "Checking if VirtualBox is already installed..."
if dpkg -s virtualbox >/dev/null 2>&1 || command -v virtualbox >/dev/null 2>&1; then
  log "virtualbox already installed. Skipping."
  exit 0
fi

log "Updating package lists..."
sudo apt-get update

log "Installing VirtualBox and related packages (dkms, qt, guest-additions iso)..."
# Note: These are distro-provided packages. For Oracle's latest builds, use Oracle's repo instead.
sudo apt-get install -y virtualbox virtualbox-dkms virtualbox-qt virtualbox-guest-additions-iso

log "VirtualBox installation complete."
log "Launch: virtualbox"
