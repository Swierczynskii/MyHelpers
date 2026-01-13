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

# VirtualBox installation via apt (from distro repositories)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  echo "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

echo "[*] Checking if VirtualBox is already installed..."
if dpkg -s virtualbox >/dev/null 2>&1 || command -v virtualbox >/dev/null 2>&1; then
  echo " - virtualbox already installed. Skipping."
  exit 0
fi

echo "[*] Updating package lists..."
sudo apt-get update

echo "[*] Installing VirtualBox and related packages (dkms, qt, guest-additions iso)..."
# Note: These are distro-provided packages. For Oracle's latest builds, use Oracle's repo instead.
sudo apt-get install -y virtualbox virtualbox-dkms virtualbox-qt virtualbox-guest-additions-iso

echo "----------------------------------------------"
echo "VirtualBox installation complete."
echo "Launch: virtualbox"
echo "----------------------------------------------"