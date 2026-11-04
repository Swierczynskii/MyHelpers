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
  title "Installing VSCodium"
fi

# VSCodium (codium) installation via the official VSCodium APT repository

# Ensure apt is available
if ! command -v apt-get >/dev/null 2>&1; then
  err "apt-get not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Skip if already installed
log "Checking if VSCodium is already installed..."
if dpkg -s codium >/dev/null 2>&1 || command -v codium >/dev/null 2>&1; then
  log "codium already installed. Skipping."
  exit 0
fi

ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
  err "Unsupported architecture: $ARCH (VSCodium APT repository provides amd64 and arm64)."
  exit 1
fi

log "Ensuring prerequisites..."
# Avoid apt update here to prevent triggering existing repo conflicts.
if ! command -v curl >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1; then
  sudo apt-get install -y curl gpg || true
fi

KEYRING="/usr/share/keyrings/vscodium-archive-keyring.gpg"
SOURCES="/etc/apt/sources.list.d/vscodium.sources"
KEY_URL="https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg"

log "Ensuring VSCodium GPG key..."
if [[ -f "$KEYRING" ]]; then
  log "Using existing keyring: $KEYRING"
else
  log "Downloading VSCodium key and writing to $KEYRING"
  curl -fsSL "$KEY_URL" | gpg --dearmor | sudo tee "$KEYRING" >/dev/null
  sudo chmod 0644 "$KEYRING"
fi

log "Cleaning duplicate VSCodium APT sources..."
sudo bash -c 'for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do [ -e "$f" ] || continue; [ "$f" = "'"$SOURCES"'" ] && continue; if grep -qs "download\.vscodium\.com" "$f"; then rm -f "$f"; fi; done'

log "Adding VSCodium APT repository..."
printf 'Types: deb\nURIs: https://download.vscodium.com/debs\nSuites: vscodium\nComponents: main\nArchitectures: %s\nSigned-By: %s\n' "$ARCH" "$KEYRING" | sudo tee "$SOURCES" >/dev/null
sudo chmod 0644 "$SOURCES"

log "Updating package lists..."
sudo apt-get update

log "Installing codium..."
sudo apt-get install -y codium

log "VSCodium installation complete."
log "Launch: codium"
