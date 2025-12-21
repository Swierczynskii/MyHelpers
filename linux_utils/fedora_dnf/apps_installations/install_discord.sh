#!/usr/bin/env bash
set -euo pipefail

# Discord installation for Fedora (dnf) via official RPM download

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
log "[*] Checking if Discord is already installed..."
if rpm -q discord >/dev/null 2>&1 || command -v discord >/dev/null 2>&1; then
  log " - discord already installed via system packages. Skipping."
  exit 0
fi
if command -v flatpak >/dev/null 2>&1; then
  if flatpak list --app --columns=application | grep -qx "com.discordapp.Discord"; then
    log " - Discord already installed via Flatpak (com.discordapp.Discord). Skipping."
    exit 0
  fi
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
  log "This installer supports x86_64 only for the official Discord RPM. Detected: $ARCH"
  log "Attempting Flatpak fallback (com.discordapp.Discord)..."
  ensure_flatpak || true
  if flatpak --user install -y flathub com.discordapp.Discord; then
    log " - Installed via Flatpak (com.discordapp.Discord)."
    echo "----------------------------------------------"
    echo "Discord installation complete (Flatpak)."
    echo "Launch: flatpak run com.discordapp.Discord"
    echo "----------------------------------------------"
    exit 0
  else
    log "ERROR: Flatpak fallback failed."
    exit 1
  fi
fi

log "[*] Ensuring a downloader is available (curl or wget)..."
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  log " - Installing wget to download the RPM..."
  sudo dnf install -y wget
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
RPM="$TMP_DIR/discord_latest_x86_64.rpm"
URL="https://discord.com/api/download?platform=linux&format=rpm"

download_to() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 -o "$dest" "$url"
  else
    wget -O "$dest" "$url"
  fi
}

log "[*] Downloading Discord RPM..."
download_to "$URL" "$RPM"

log "[*] Installing Discord (DNF will resolve dependencies automatically)..."
if sudo dnf install -y "$RPM"; then
  echo "----------------------------------------------"
  echo "Discord installation complete."
  echo "Launch: discord"
  echo "----------------------------------------------"
else
  log " - dnf install failed, attempting Flatpak fallback (com.discordapp.Discord)..."
  ensure_flatpak || true
  if flatpak --user install -y flathub com.discordapp.Discord; then
    echo "----------------------------------------------"
    echo "Discord installation complete (Flatpak)."
    echo "Launch: flatpak run com.discordapp.Discord"
    echo "----------------------------------------------"
  else
    log "ERROR: Failed to install Discord via dnf and Flatpak."
    exit 1
  fi
fi