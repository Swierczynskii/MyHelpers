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

# Firefox installation via official Mozilla APT repository (keyrings + signed-by)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  echo "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

echo "[*] Ensuring prerequisites..."
NEED_UPDATE=0
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo " - Installing wget (no curl/wget found)"
  sudo apt-get update
  sudo apt-get install -y wget
  NEED_UPDATE=1
fi

# Special handling for Firefox:
# - If Snap Firefox exists, remove it first
# - If APT Firefox already installed, skip installation
echo "[*] Checking for Snap Firefox..."
if command -v snap >/dev/null 2>&1; then
  if snap list firefox >/dev/null 2>&1; then
    echo " - Found Firefox installed via Snap. Removing..."
    if ! sudo snap remove --purge firefox; then
      echo " - Purge failed; attempting regular remove..."
      sudo snap remove firefox || { echo "ERROR: Unable to remove Snap Firefox."; exit 1; }
    fi
    echo " - Removed Snap Firefox."
  else
    echo " - Snap Firefox not present."
  fi
else
  echo " - snap not found; skipping snap check."
fi

echo "[*] Checking if Firefox (APT) is already installed..."
if dpkg -s firefox >/dev/null 2>&1; then
  echo " - Firefox (APT) already installed. Skipping."
  exit 0
fi

echo "[*] Preparing keyrings directory..."
sudo install -d -m 0755 /etc/apt/keyrings

KEYRING="/etc/apt/keyrings/packages.mozilla.org.asc"
LIST="/etc/apt/sources.list.d/mozilla.list"
PREF="/etc/apt/preferences.d/mozilla"

echo "[*] Installing Mozilla signing key..."
if [[ ! -f "$KEYRING" ]]; then
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo tee "$KEYRING" >/dev/null
  else
    wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo tee "$KEYRING" >/dev/null
  fi
  sudo chmod 0644 "$KEYRING"
else
  echo " - Keyring already exists: $KEYRING"
fi

echo "[*] Adding Mozilla APT repository..."
if [[ ! -f "$LIST" ]]; then
  echo "deb [signed-by=$KEYRING] https://packages.mozilla.org/apt mozilla main" | sudo tee "$LIST" >/dev/null
else
  echo " - Repository list already exists: $LIST"
fi

echo "[*] Setting APT pinning to prefer Mozilla origin..."
if [[ ! -f "$PREF" ]]; then
  sudo tee "$PREF" >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
else
  echo " - Preferences already exist: $PREF"
fi

echo "[*] Updating package lists..."
sudo apt-get update

echo "[*] Installing firefox..."
sudo apt-get install -y firefox

echo "----------------------------------------------"
echo "Firefox installation complete."
echo "Launch: firefox"
echo "----------------------------------------------"
