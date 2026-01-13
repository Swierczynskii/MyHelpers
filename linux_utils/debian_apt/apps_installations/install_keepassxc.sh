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

# KeePassXC installation via apt (from official distro repositories)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  echo "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Skip if already installed
echo "[*] Checking if KeePassXC is already installed..."
if dpkg -s keepassxc >/dev/null 2>&1 || command -v keepassxc >/dev/null 2>&1; then
  echo " - keepassxc already installed. Skipping."
  exit 0
fi

echo "[*] Updating package lists..."
sudo apt-get update

echo "[*] Installing KeePassXC..."
sudo apt-get install -y keepassxc

echo "----------------------------------------------"
echo "KeePassXC installation complete."
echo "Launch: keepassxc"
echo "----------------------------------------------"