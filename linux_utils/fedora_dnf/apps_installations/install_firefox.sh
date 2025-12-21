#!/usr/bin/env bash
set -euo pipefail

# Firefox installation for Fedora (dnf)

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

# Skip if already installed (dnf or Flatpak)
log "[*] Checking if Firefox is already installed..."
if rpm -q firefox >/dev/null 2>&1 || command -v firefox >/dev/null 2>&1; then
  log " - firefox already installed via system packages. Skipping."
  exit 0
fi
if command -v flatpak >/dev/null 2>&1; then
  if flatpak list --app --columns=application | grep -qx "org.mozilla.firefox"; then
    log " - Firefox already installed via Flatpak (org.mozilla.firefox). Skipping."
    exit 0
  fi
fi

log "[*] Installing firefox..."
if sudo dnf install -y firefox; then
  log " - Installed via dnf."
else
  log " - dnf install failed, attempting Flatpak fallback (org.mozilla.firefox)..."
  ensure_flatpak || true
  if flatpak --user install -y flathub org.mozilla.firefox; then
    log " - Installed via Flatpak (org.mozilla.firefox)."
  else
    log "ERROR: Failed to install Firefox via dnf and Flatpak."
    exit 1
  fi
fi

echo "----------------------------------------------"
echo "Firefox installation complete."
echo "Launch: firefox (dnf) or via Flatpak if installed with Flatpak"
echo "----------------------------------------------"