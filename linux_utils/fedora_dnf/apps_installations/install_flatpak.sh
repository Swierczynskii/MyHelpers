#!/usr/bin/env bash
set -euo pipefail

# Flatpak + Flathub setup for Fedora (dnf)
# - Installs flatpak (if missing)
# - Adds Flathub user remote (idempotent)
# Intended to enable flatpak fallbacks for apps without native dnf packages.

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure dnf is available
if ! require_cmd dnf; then
  log "dnf not found. This script targets Fedora (dnf)."
  exit 1
fi

log "[*] Ensuring flatpak is installed..."
if ! require_cmd flatpak; then
  sudo dnf install -y flatpak
else
  log " - flatpak already installed."
fi

# Prefer user-level Flathub remote to avoid requiring sudo; idempotent add
FLATHUB_URL="https://flathub.org/repo/flathub.flatpakrepo"
if ! flatpak --user remote-list | awk '{print $1}' | grep -qx "flathub"; then
  log "[*] Adding Flathub user remote..."
  flatpak --user remote-add --if-not-exists flathub "$FLATHUB_URL" || true
else
  log " - Flathub user remote already present."
fi

echo "----------------------------------------------"
echo "Flatpak setup complete (flatpak installed, Flathub user remote configured)."
echo "You can now install apps with: flatpak --user install -y flathub <AppID>"
echo "----------------------------------------------"