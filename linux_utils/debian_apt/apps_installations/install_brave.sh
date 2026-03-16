#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_brave.sh
# Install Brave Browser via official Brave APT repository (keyrings + signed-by)
# Prerequisites: sudo, apt-get, curl or wget, network access
# Usage: ./install_brave.sh
# Non-interactive: export DEBIAN_FRONTEND=noninteractive
# -----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
fi

TIMESTAMP_COLOR='\033[1;36m'
TITLE_COLOR='\033[0;34m'
ERROR_COLOR='\033[1;31m'
NC='\033[0m'

strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

repeat_char() {
  local char="$1"
  local count="$2"
  local output=''
  local index

  for ((index = 0; index < count; index++)); do
    output+="$char"
  done

  printf '%s' "$output"
}

print_box() {
  local full_text="$1"
  local color="${2:-}"
  local rendered_text
  local line
  local clean_line
  local max_len=0
  local line_len
  local horizontal_line

  rendered_text="$(printf '%b' "$full_text")"

  while IFS= read -r line; do
    clean_line="$(printf '%s\n' "$line" | strip_ansi)"
    line_len=${#clean_line}
    if (( line_len > max_len )); then
      max_len=$line_len
    fi
  done <<< "$rendered_text"

  horizontal_line="$(repeat_char '═' "$((max_len + 4))")"

  if (( COLOR_ENABLED )) && [[ -n "$color" ]]; then
    printf '%b╔%s╗%b\n' "$color" "$horizontal_line" "$NC"
    while IFS= read -r line; do
      printf '%b║  %b%-*s%b  ║%b\n' "$color" "$NC" "$max_len" "$line" "$color" "$NC"
    done <<< "$rendered_text"
    printf '%b╚%s╝%b\n' "$color" "$horizontal_line" "$NC"
  else
    printf '╔%s╗\n' "$horizontal_line"
    while IFS= read -r line; do
      printf '║  %-*s  ║\n' "$max_len" "$line"
    done <<< "$rendered_text"
    printf '╚%s╝\n' "$horizontal_line"
  fi
}

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
  print_box "ERROR\n$*" "$ERROR_COLOR" >&2
}

title() {
  print_box "$*" "$TITLE_COLOR"
}

if [[ "${SKIP_INSTALLER_TITLE:-0}" != "1" ]]; then
  title "Installing Brave Browser"
fi

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Skip if already installed
log "Checking if Brave Browser is already installed..."
if dpkg -s brave-browser >/dev/null 2>&1 || command -v brave-browser >/dev/null 2>&1; then
  log "brave-browser already installed. Skipping."
  exit 0
fi

log "Ensuring prerequisites..."
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  log "Installing wget (no curl/wget found)"
  sudo apt-get update
  sudo apt-get install -y wget
fi

log "Preparing keyrings directory..."
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

log "Ensuring Brave signing key..."
if [[ -f "$KEYRING_DEFAULT" ]]; then
  KEYRING="$KEYRING_DEFAULT"
  log "Using existing keyring: $KEYRING"
elif [[ -f "$KEYRING_LEGACY" ]]; then
  KEYRING="$KEYRING_LEGACY"
  log "Using legacy keyring: $KEYRING"
else
  log "Downloading keyring to $KEYRING_DEFAULT"
  download_to "${BRAVE_URL}brave-browser-archive-keyring.gpg" "$KEYRING_DEFAULT"
  sudo chmod 0644 "$KEYRING_DEFAULT"
  KEYRING="$KEYRING_DEFAULT"
fi

log "Cleaning duplicate Brave APT sources..."
sudo sed -i -E '/brave-browser-apt-release\.s3\.brave\.com/d' /etc/apt/sources.list || true
# Remove any .list or .sources files referencing Brave to avoid duplicate entries with different Signed-By
sudo bash -lc 'for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do [ -e "$f" ] || continue; if grep -qs "brave-browser-apt-release\.s3\.brave\.com" "$f"; then rm -f "$f"; fi; done'

log "Adding Brave APT repository..."
echo "deb [arch=$ARCH signed-by=$KEYRING] ${BRAVE_URL} stable main" | sudo tee "$LIST" >/dev/null
sudo chmod 0644 "$LIST"

log "Updating package lists..."
sudo apt-get update

log "Installing brave-browser..."
sudo apt-get install -y brave-browser

log "Brave Browser installation complete."
log "Launch: brave-browser"
