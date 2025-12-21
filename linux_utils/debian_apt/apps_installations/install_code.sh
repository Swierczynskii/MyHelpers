#!/usr/bin/env bash
set -euo pipefail

# Visual Studio Code (stable + optional Insiders) installation via Microsoft APT repository

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  echo "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Skip if already installed
echo "[*] Checking if Visual Studio Code is already installed..."
if dpkg -s code >/dev/null 2>&1 || command -v code >/dev/null 2>&1; then
  echo " - code already installed. Skipping."
  exit 0
fi

echo "[*] Ensuring prerequisites..."
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

echo "[*] Ensuring Microsoft GPG key..."
if [[ -f "$KEYRING_VSCODE_USR" ]]; then
  KEYRING="$KEYRING_VSCODE_USR"
  echo " - Using existing keyring: $KEYRING"
elif [[ -f "$KEYRING_MS_USR" ]]; then
  KEYRING="$KEYRING_MS_USR"
  echo " - Using existing keyring: $KEYRING"
elif [[ -f "$KEYRING_MS_ETC" ]]; then
  KEYRING="$KEYRING_MS_ETC"
  echo " - Using existing keyring: $KEYRING"
else
  echo " - Downloading Microsoft key and writing to $KEYRING_VSCODE_USR"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee "$KEYRING_VSCODE_USR" >/dev/null
  sudo chmod 0644 "$KEYRING_VSCODE_USR"
  KEYRING="$KEYRING_VSCODE_USR"
fi

echo "[*] Cleaning duplicate VS Code APT sources..."
sudo sed -i -E '/packages\.microsoft\.com\/repos\/code/d' /etc/apt/sources.list || true
sudo bash -lc 'for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do [ -e "$f" ] || continue; if grep -qs "packages\.microsoft\.com/repos/code" "$f"; then rm -f "$f"; fi; done'

echo "[*] Adding VS Code APT repository..."
echo "deb [${ARCHES} signed-by=${KEYRING}] ${CODE_URL} stable main" | sudo tee "$LIST" >/dev/null
sudo chmod 0644 "$LIST"

echo "[*] Updating package lists..."
sudo apt update

echo "[*] Installing code (stable)..."
sudo apt install -y code

# Prompt to optionally install Insiders
read -r -p "Would you like to install Visual Studio Code Insiders as well? [y/N]: " INSTALL_INSIDERS || true
if [[ "${INSTALL_INSIDERS:-N}" =~ ^[Yy]$ ]]; then
  echo "[*] Installing code-insiders..."
  sudo apt install -y code-insiders
fi

echo "----------------------------------------------"
echo "Visual Studio Code installation complete."
echo "Launch: code"
echo "If installed, Insiders launch: code-insiders"
echo "----------------------------------------------"