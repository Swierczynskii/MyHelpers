#!/usr/bin/env bash
set -euo pipefail

# Brave Browser installation via official Brave APT repository (keyrings + signed-by)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  echo "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Skip if already installed
echo "[*] Checking if Brave Browser is already installed..."
if dpkg -s brave-browser >/dev/null 2>&1 || command -v brave-browser >/dev/null 2>&1; then
  echo " - brave-browser already installed. Skipping."
  exit 0
fi

echo "[*] Ensuring prerequisites..."
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo " - Installing wget (no curl/wget found)"
  sudo apt update
  sudo apt install -y wget
fi

echo "[*] Preparing keyrings directory..."
sudo install -d -m 0755 /etc/apt/keyrings

ARCH=$(dpkg --print-architecture)
BRAVE_URL="https://brave-browser-apt-release.s3.brave.com/"
KEYRING_DEFAULT="/etc/apt/keyrings/brave-browser-archive-keyring.gpg"
KEYRING_LEGACY="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
LIST="/etc/apt/sources.list.d/brave-browser-release.list"

download_to() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    sudo curl -fsSL "$url" -o "$dest"
  else
    sudo wget -qO "$dest" "$url"
  fi
}

echo "[*] Ensuring Brave signing key..."
if [[ -f "$KEYRING_DEFAULT" ]]; then
  KEYRING="$KEYRING_DEFAULT"
  echo " - Using existing keyring: $KEYRING"
elif [[ -f "$KEYRING_LEGACY" ]]; then
  KEYRING="$KEYRING_LEGACY"
  echo " - Using legacy keyring: $KEYRING"
else
  echo " - Downloading keyring to $KEYRING_DEFAULT"
  download_to "${BRAVE_URL}brave-browser-archive-keyring.gpg" "$KEYRING_DEFAULT"
  sudo chmod 0644 "$KEYRING_DEFAULT"
  KEYRING="$KEYRING_DEFAULT"
fi

echo "[*] Cleaning duplicate Brave APT sources..."
sudo sed -i -E '/brave-browser-apt-release\.s3\.brave\.com/d' /etc/apt/sources.list || true
# Remove any .list or .sources files referencing Brave to avoid duplicate entries with different Signed-By
sudo bash -lc 'for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do [ -e "$f" ] || continue; if grep -qs "brave-browser-apt-release\.s3\.brave\.com" "$f"; then rm -f "$f"; fi; done'

echo "[*] Adding Brave APT repository..."
echo "deb [arch=$ARCH signed-by=$KEYRING] ${BRAVE_URL} stable main" | sudo tee "$LIST" >/dev/null
sudo chmod 0644 "$LIST"

echo "[*] Updating package lists..."
sudo apt update

echo "[*] Installing brave-browser..."
sudo apt install -y brave-browser

echo "----------------------------------------------"
echo "Brave Browser installation complete."
echo "Launch: brave-browser"
echo "----------------------------------------------"