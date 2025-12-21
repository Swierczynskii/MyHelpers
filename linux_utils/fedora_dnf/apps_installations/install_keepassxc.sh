#!/usr/bin/env bash
set -euo pipefail

# KeePassXC installation for Fedora (dnf)

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Ensure dnf is available
if ! command -v dnf >/dev/null 2>&1; then
  log "dnf not found. This script targets Fedora (dnf)."
  exit 1
fi

# Flatpak bootstrap (for fallback installs)
ensure_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    sudo dnf install -y flatpak || return 1
  fi
  if ! flatpak --user remote-list | awk '{print $1}' | grep -qx "flathub"; then
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || return 1
  fi
  return 0
}

# Skip if already installed
log "[*] Checking if KeePassXC is already installed..."
if rpm -q keepassxc >/dev/null 2>&1 || command -v keepassxc >/dev/null 2>&1; then
  log " - keepassxc already installed via system packages. Skipping."
  exit 0
fi
if command -v flatpak >/dev/null 2>&1; then
  if flatpak list --app --columns=application | grep -qx "org.keepassxc.KeePassXC"; then
    log " - KeePassXC already installed via Flatpak (org.keepassxc.KeePassXC). Skipping."
    exit 0
  fi
fi

log "[*] Installing KeePassXC..."
if sudo dnf install -y keepassxc; then
  log " - Installed via dnf."
else
  log " - dnf install failed, attempting Flatpak fallback (org.keepassxc.KeePassXC)..."
  ensure_flatpak || true
  if flatpak --user install -y flathub org.keepassxc.KeePassXC; then
    log " - Installed via Flatpak (org.keepassxc.KeePassXC)."
  else
    log "ERROR: Failed to install KeePassXC via dnf and Flatpak."
    exit 1
  fi
fi

echo "----------------------------------------------"
echo "KeePassXC installation complete."
echo "Launch: keepassxc"
echo "----------------------------------------------"