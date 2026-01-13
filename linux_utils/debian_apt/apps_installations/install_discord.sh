#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_discord.sh
# Install Discord by downloading the official .deb and installing via apt-get
# Prerequisites: sudo, apt-get, curl or wget (one will be installed if missing)
# Usage: ./install_discord.sh
# Non-interactive: export DEBIAN_FRONTEND=noninteractive
# -----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# Discord installation by downloading the official .deb and installing via apt

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  echo "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" != "amd64" ]]; then
  echo "Discord provides official .deb only for amd64. Detected architecture: $ARCH"
  echo "Consider using Flatpak or Snap on this system."
  exit 1
fi

echo "[*] Checking if Discord is already installed..."
if dpkg -s discord >/dev/null 2>&1 || command -v discord >/dev/null 2>&1; then
  echo " - discord already installed. Skipping."
  exit 0
fi

echo "[*] Ensuring prerequisites..."
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo " - Installing wget (no curl/wget found)"
  sudo apt-get update
  sudo apt-get install -y wget
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
DEB="$TMP_DIR/discord_latest_amd64.deb"
URL="https://discord.com/api/download?platform=linux&format=deb"

download_to() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 -o "$dest" "$url"
  else
    wget -O "$dest" "$url"
  fi
}

echo "[*] Downloading Discord .deb..."
download_to "$URL" "$DEB"

echo "[*] Installing Discord (this will resolve dependencies automatically)..."
sudo apt-get install -y "$DEB"

echo "----------------------------------------------"
echo "Discord installation complete."
echo "Launch: discord"
echo "----------------------------------------------"