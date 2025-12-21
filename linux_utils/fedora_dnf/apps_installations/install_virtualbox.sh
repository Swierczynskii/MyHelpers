#!/usr/bin/env bash
set -euo pipefail

# Oracle VirtualBox installation for Fedora (dnf)
# - Configures Oracle YUM repo for Fedora
# - Installs build prerequisites
# - Installs VirtualBox-7.0
# - Adds current user to vboxusers (idempotent)

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

# Skip if already installed
log "[*] Checking if VirtualBox is already installed..."
if rpm -q VirtualBox-7.0 >/dev/null 2>&1 || command -v VirtualBox >/dev/null 2>&1 || command -v VBoxManage >/dev/null 2>&1; then
  log " - VirtualBox already installed. Skipping."
  exit 0
fi

# Per policy: do not configure third‑party repositories.
# Attempt install only if VirtualBox is available in official Fedora repos.
log "[*] Checking availability of VirtualBox in Fedora repositories..."
PKG=""
if dnf list --available VirtualBox-7.0 >/dev/null 2>&1; then
  PKG="VirtualBox-7.0"
elif dnf list --available VirtualBox >/dev/null 2>&1; then
  PKG="VirtualBox"
else
  PKG=""
fi

if [[ -z "$PKG" ]]; then
  log "VirtualBox is not available in the enabled Fedora repositories."
  log "No Flatpak equivalent is known; skipping VirtualBox installation per no third‑party policy."
  exit 0
fi

# Install prerequisites for kernel module build
log "[*] Installing kernel module build prerequisites..."
sudo dnf install -y kernel-devel kernel-headers gcc make perl elfutils-libelf-devel

# Install VirtualBox from Fedora repos
log "[*] Installing $PKG..."
sudo dnf install -y "$PKG"

# Post-install: ensure user is in vboxusers
if getent group vboxusers >/dev/null 2>&1; then
  if id -nG "$USER" | tr ' ' '\n' | grep -qx "vboxusers"; then
    log " - User '$USER' is already in vboxusers."
  else
    log " - Adding user '$USER' to vboxusers group..."
    sudo usermod -aG vboxusers "$USER" || true
    log "   You may need to log out and back in for group changes to take effect."
  fi
fi

# Attempt to build/load kernel modules
log "[*] Attempting to build and load VirtualBox kernel modules..."
if [[ -x /sbin/vboxconfig ]]; then
  sudo /sbin/vboxconfig || true
fi

echo "----------------------------------------------"
echo "VirtualBox installation complete."
echo "Launch: VirtualBox"
echo "If kernel modules failed to build, reboot and run: sudo /sbin/vboxconfig"
echo "----------------------------------------------"