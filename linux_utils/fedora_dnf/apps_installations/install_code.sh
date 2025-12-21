#!/usr/bin/env bash
set -euo pipefail

# Visual Studio Code installation via Microsoft YUM repository (Fedora dnf)

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Ensure dnf is available
if ! command -v dnf >/dev/null 2>&1; then
  log "dnf not found. This script targets Fedora (dnf)."
  exit 1
fi

# Skip if already installed
log "[*] Checking if Visual Studio Code is already installed..."
if rpm -q code >/dev/null 2>&1 || command -v code >/dev/null 2>&1; then
  log " - code already installed. Skipping."
  exit 0
fi

log "[*] Ensuring prerequisites (dnf-plugins-core for config-manager)..."
sudo dnf install -y dnf-plugins-core >/dev/null 2>&1 || true

# Flatpak bootstrap (for fallback installs)
ensure_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    sudo dnf install -y flatpak || return 1
  fi
  # Add Flathub user remote if missing
  if ! flatpak --user remote-list | awk '{print $1}' | grep -qx "flathub"; then
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || return 1
  fi
  return 0
}

REPO_FILE="/etc/yum.repos.d/vscode.repo"
GPG_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"

log "[*] Configuring Microsoft VS Code repository..."
# Create/refresh repo file (idempotent)
sudo bash -c "cat > '$REPO_FILE' << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
metadata_expire=1h
EOF"

log " - Importing Microsoft GPG key (idempotent)..."
sudo rpm --import "$GPG_KEY_URL" || true

log "[*] Refreshing repository metadata..."
sudo dnf check-update || true

log "[*] Installing code (stable)..."
if sudo dnf install -y code; then
  log " - Installed via dnf."
else
  log " - dnf install failed, attempting Flatpak fallback (com.visualstudio.code)..."
  ensure_flatpak || true
  if flatpak --user install -y flathub com.visualstudio.code; then
    log " - Installed via Flatpak (com.visualstudio.code)."
  else
    log "ERROR: Failed to install Visual Studio Code via dnf and Flatpak."
    exit 1
  fi
fi

# Prompt to optionally install Insiders
read -r -p "Would you like to install Visual Studio Code Insiders as well? [y/N]: " INSTALL_INSIDERS || true
if [[ "${INSTALL_INSIDERS:-N}" =~ ^[Yy]$ ]]; then
  log "[*] Configuring VS Code Insiders repository (shares the same key)..."
  REPO_FILE_INSIDERS="/etc/yum.repos.d/vscode-insiders.repo"
  sudo bash -c "cat > '$REPO_FILE_INSIDERS' << 'EOF'
[code-insiders]
name=Visual Studio Code Insiders
baseurl=https://packages.microsoft.com/yumrepos/vscode-insiders
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
metadata_expire=1h
EOF"
  sudo dnf check-update || true
  log "[*] Installing code-insiders..."
  sudo dnf install -y code-insiders || log " - code-insiders not available for your architecture or channel."
fi

echo "----------------------------------------------"
echo "Visual Studio Code installation complete."
echo "Launch: code"
echo "If installed, Insiders launch: code-insiders"
echo "----------------------------------------------"