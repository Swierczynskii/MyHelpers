#!/usr/bin/env bash
set -euo pipefail

# Spotify installation for Fedora (dnf) — no third-party repos; Flatpak-only

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure dnf available to install flatpak if needed
if ! require_cmd dnf; then
  log "dnf not found. This script targets Fedora (dnf)."
  exit 1
fi

# Ensure Flatpak + Flathub (user remote)
ensure_flatpak() {
  if ! require_cmd flatpak; then
    sudo dnf install -y flatpak
  fi
  if ! flatpak --user remote-list | awk '{print $1}' | grep -qx "flathub"; then
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

# Skip if already installed (rpm or Flatpak)
log "[*] Checking if Spotify is already installed..."
if rpm -q spotify >/dev/null 2>&1 || require_cmd spotify; then
  log " - spotify already installed via system packages. Skipping."
  exit 0
fi
if require_cmd flatpak; then
  if flatpak list --app --columns=application | grep -qx "com.spotify.Client"; then
    log " - Spotify already installed via Flatpak (com.spotify.Client). Skipping."
    exit 0
  fi
fi

# Flatpak-only install
log "[*] Installing Spotify via Flatpak (com.spotify.Client)..."
ensure_flatpak
if flatpak --user install -y flathub com.spotify.Client; then
  echo "----------------------------------------------"
  echo "Spotify installation complete (Flatpak)."
  echo "Launch: flatpak run com.spotify.Client"
  echo "----------------------------------------------"
else
  log "ERROR: Failed to install Spotify via Flatpak."
  exit 1
fi