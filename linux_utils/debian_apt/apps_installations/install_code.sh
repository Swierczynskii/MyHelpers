#!/usr/bin/env bash
set -euo pipefail
umask 022
# Non-interactive installs use apt-get; DEBIAN_FRONTEND ensures no prompts
export DEBIAN_FRONTEND=noninteractive

COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
fi

TIMESTAMP_COLOR='\033[1;36m'
TITLE_COLOR='\033[1;33m'
ERROR_COLOR='\033[1;31m'
NC='\033[0m'

timestamp() {
  local ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
  if (( COLOR_ENABLED )); then
    printf '%b%s%b' "$TIMESTAMP_COLOR" "$ts" "$NC"
  else
    printf '%s' "$ts"
  fi
}

log() {
  printf '%s %s\n' "$(timestamp)" "$*"
}

err() {
  if (( COLOR_ENABLED )); then
    printf '%s %bERROR:%b %s\n' "$(timestamp)" "$ERROR_COLOR" "$NC" "$*" >&2
  else
    printf '%s ERROR: %s\n' "$(timestamp)" "$*" >&2
  fi
}

title() {
  if (( COLOR_ENABLED )); then
    printf '%s %b%s%b\n' "$(timestamp)" "$TITLE_COLOR" "$*" "$NC"
  else
    printf '%s %s\n' "$(timestamp)" "$*"
  fi
}

if [[ "${SKIP_INSTALLER_TITLE:-0}" != "1" ]]; then
  title "Installing Visual Studio Code"
fi

# Visual Studio Code (stable + optional Insiders) installation via Microsoft APT repository

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Skip if already installed
log "Checking if Visual Studio Code is already installed..."
if dpkg -s code >/dev/null 2>&1 || command -v code >/dev/null 2>&1; then
  log "code already installed. Skipping."
  exit 0
fi

log "Ensuring prerequisites..."
# Avoid apt update here to prevent triggering existing repo conflicts.
# Install only if missing; tolerate failures (packages usually already present).
if ! command -v wget >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1; then
  sudo apt-get install -y wget gpg || true
fi

CODE_URL="https://packages.microsoft.com/repos/code"
# Prefer whichever keyring already exists to avoid Signed-By conflicts
KEYRING_VSCODE_USR="/usr/share/keyrings/vscode.gpg"
KEYRING_MS_USR="/usr/share/keyrings/microsoft.gpg"
KEYRING_MS_ETC="/etc/apt/keyrings/microsoft.gpg"
LIST="/etc/apt/sources.list.d/vscode.list"
ARCHES="arch=amd64,arm64,armhf"

log "Ensuring Microsoft GPG key..."
if [[ -f "$KEYRING_VSCODE_USR" ]]; then
  KEYRING="$KEYRING_VSCODE_USR"
  log "Using existing keyring: $KEYRING"
elif [[ -f "$KEYRING_MS_USR" ]]; then
  KEYRING="$KEYRING_MS_USR"
  log "Using existing keyring: $KEYRING"
elif [[ -f "$KEYRING_MS_ETC" ]]; then
  KEYRING="$KEYRING_MS_ETC"
  log "Using existing keyring: $KEYRING"
else
  log "Downloading Microsoft key and writing to $KEYRING_VSCODE_USR"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee "$KEYRING_VSCODE_USR" >/dev/null
  sudo chmod 0644 "$KEYRING_VSCODE_USR"
  KEYRING="$KEYRING_VSCODE_USR"
fi

log "Cleaning duplicate VS Code APT sources..."
sudo sed -i -E '/packages\.microsoft\.com\/repos\/code/d' /etc/apt/sources.list || true
sudo bash -lc 'for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do [ -e "$f" ] || continue; if grep -qs "packages\.microsoft\.com/repos/code" "$f"; then rm -f "$f"; fi; done'

log "Adding VS Code APT repository..."
echo "deb [${ARCHES} signed-by=${KEYRING}] ${CODE_URL} stable main" | sudo tee "$LIST" >/dev/null
sudo chmod 0644 "$LIST"

log "Updating package lists..."
sudo apt-get update

log "Installing code (stable)..."
sudo apt-get install -y code

# Prompt to optionally install Insiders (TTY-only; default No when non-interactive)
if [[ -t 0 ]]; then
  read -r -p "Would you like to install Visual Studio Code Insiders as well? [y/N]: " INSTALL_INSIDERS || true
else
  INSTALL_INSIDERS="N"
  log "Non-interactive stdin detected; skipping optional Insiders install (default: No)."
fi
if [[ "${INSTALL_INSIDERS:-N}" =~ ^[Yy]$ ]]; then
  log "Installing code-insiders..."
  sudo apt-get install -y code-insiders
fi

log "Visual Studio Code installation complete."
log "Launch: code"
log "If installed, Insiders launch: code-insiders"
