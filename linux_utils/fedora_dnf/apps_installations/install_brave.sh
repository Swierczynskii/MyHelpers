#!/usr/bin/env bash
set -euo pipefail

# Brave Browser installation via official Brave YUM/DNF repository (Fedora)

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Ensure dnf is available
if ! command -v dnf >/dev/null 2>&1; then
  log "dnf not found. This script targets Fedora (dnf)."
  exit 1
fi

# Skip if already installed
log "[*] Checking if Brave Browser is already installed..."
if rpm -q brave-browser >/dev/null 2>&1 || command -v brave-browser >/dev/null 2>&1; then
  log " - brave-browser already installed via system packages. Skipping."
  exit 0
fi
# Skip if installed via Flatpak
if command -v flatpak >/dev/null 2>&1; then
  if flatpak list --app --columns=application | grep -qx "com.brave.Browser"; then
    log " - Brave already installed via Flatpak (com.brave.Browser). Skipping."
    exit 0
  fi
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

log "[*] Importing Brave GPG key (idempotent)..."
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc || true

log "[*] Writing Brave repository file (idempotent)..."
REPO_FILE="/etc/yum.repos.d/brave-browser.repo"
sudo bash -c "cat > '$REPO_FILE' << 'EOF'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/
enabled=1
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
metadata_expire=1h
EOF"

log "[*] Refreshing repository metadata..."
sudo dnf check-update || true

log "[*] Installing brave-browser..."
if sudo dnf install -y brave-browser; then
  log " - Installed via dnf."
else
  log " - dnf install failed, attempting Flatpak fallback (com.brave.Browser)..."
  ensure_flatpak || true
  if flatpak --user install -y flathub com.brave.Browser; then
    log " - Installed via Flatpak (com.brave.Browser)."
  else
    log "ERROR: Failed to install Brave via dnf and Flatpak."
    exit 1
  fi
fi

echo "----------------------------------------------"
echo "Brave Browser installation complete."
echo "Launch: brave-browser"
echo "----------------------------------------------"