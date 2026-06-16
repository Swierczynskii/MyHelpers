#!/usr/bin/env bash
set -euo pipefail
umask 022
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
  local ts
  ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
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
  title "Installing Google Chrome"
fi

if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

log "Checking if Google Chrome is already installed..."
if dpkg -s google-chrome-stable >/dev/null 2>&1 || command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1; then
  log "google-chrome-stable already installed. Skipping."
  exit 0
fi

log "Ensuring prerequisites..."
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  log "Installing wget (no curl/wget found)"
  sudo apt-get update
  sudo apt-get install -y wget
fi
if ! command -v gpg >/dev/null 2>&1; then
  log "Installing gpg..."
  sudo apt-get update
  sudo apt-get install -y gpg
fi

sudo install -d -m 0755 /etc/apt/keyrings

ARCH="$(dpkg --print-architecture)"
KEY_URL="https://dl.google.com/linux/linux_signing_key.pub"
KEYRING_DEFAULT="/etc/apt/keyrings/google-linux-signing-keyring.gpg"
KEYRING_LEGACY="/usr/share/keyrings/google-chrome.gpg"
LIST="/etc/apt/sources.list.d/google-chrome.list"

download_key() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$KEY_URL"
  else
    wget -qO- "$KEY_URL"
  fi
}

log "Ensuring Google signing key..."
if [[ -f "$KEYRING_DEFAULT" ]]; then
  KEYRING="$KEYRING_DEFAULT"
elif [[ -f "$KEYRING_LEGACY" ]]; then
  KEYRING="$KEYRING_LEGACY"
else
  download_key | gpg --dearmor | sudo tee "$KEYRING_DEFAULT" >/dev/null
  sudo chmod 0644 "$KEYRING_DEFAULT"
  KEYRING="$KEYRING_DEFAULT"
fi

log "Cleaning duplicate Google Chrome APT sources..."
sudo sed -i -E '/dl\.google\.com\/linux\/chrome\/deb/d' /etc/apt/sources.list || true
sudo bash -lc 'for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do [ -e "$f" ] || continue; if grep -qs "dl\.google\.com/linux/chrome/deb" "$f"; then rm -f "$f"; fi; done'

log "Adding Google Chrome APT repository..."
echo "deb [arch=${ARCH} signed-by=${KEYRING}] https://dl.google.com/linux/chrome/deb/ stable main" | sudo tee "$LIST" >/dev/null
sudo chmod 0644 "$LIST"

log "Updating package lists..."
sudo apt-get update

log "Installing google-chrome-stable..."
sudo apt-get install -y google-chrome-stable

log "Google Chrome installation complete."
log "Launch: google-chrome-stable"
