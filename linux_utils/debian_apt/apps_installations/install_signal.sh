#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_signal.sh
# Install Signal Desktop via the official Signal APT repository.
# Prerequisites: sudo, apt-get, gpg, curl or wget, network access
# Usage: ./install_signal.sh
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
  title "Installing Signal Desktop"
fi

if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" != "amd64" ]]; then
  err "Signal Desktop APT installation currently supports amd64 Debian/Ubuntu systems only. Detected architecture: $ARCH"
  exit 1
fi

log "Checking if Signal Desktop is already installed..."
if dpkg -s signal-desktop >/dev/null 2>&1 || command -v signal-desktop >/dev/null 2>&1; then
  log "signal-desktop already installed. Skipping."
  exit 0
fi

log "Ensuring prerequisites..."
if ! command -v gpg >/dev/null 2>&1 || { ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; }; then
  sudo apt-get update
  sudo apt-get install -y wget gpg
fi

download_to() {
  local url="$1"
  local dest="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  else
    wget -qO "$dest" "$url"
  fi
}

KEY_URL="https://updates.signal.org/desktop/apt/keys.asc"
SOURCE_URL="https://updates.signal.org/static/desktop/apt/signal-desktop.sources"
KEYRING="/usr/share/keyrings/signal-desktop-keyring.gpg"
LIST="/etc/apt/sources.list.d/signal-desktop.sources"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Preparing Signal keyring..."
if [[ -f "$KEYRING" ]]; then
  log "Using existing keyring: $KEYRING"
else
  KEY_ASC="$TMP_DIR/keys.asc"
  KEY_GPG="$TMP_DIR/signal-desktop-keyring.gpg"
  download_to "$KEY_URL" "$KEY_ASC"
  gpg --dearmor < "$KEY_ASC" > "$KEY_GPG"
  sudo install -m 0644 "$KEY_GPG" "$KEYRING"
fi

log "Cleaning duplicate Signal APT sources..."
sudo sed -i -E '/updates\.signal\.org/d' /etc/apt/sources.list || true
sudo bash -lc 'for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do [ -e "$f" ] || continue; if grep -qs "updates\.signal\.org" "$f"; then rm -f "$f"; fi; done'

log "Adding Signal APT repository..."
SOURCE_TMP="$TMP_DIR/signal-desktop.sources"
download_to "$SOURCE_URL" "$SOURCE_TMP"
sudo install -m 0644 "$SOURCE_TMP" "$LIST"

log "Updating package lists..."
sudo apt-get update

log "Installing signal-desktop..."
sudo apt-get install -y signal-desktop

log "Signal Desktop installation complete."
log "Launch: signal-desktop"
