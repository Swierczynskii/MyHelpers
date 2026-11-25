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

# 'dpkg -s' also succeeds for removed-but-not-purged packages.
pkg_installed() {
  [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" == "installed" ]]
}

# Remove only the entries using the given repository (regex); other entries in the same file are kept.
remove_apt_entries() {
  local f tmp
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [[ -f "$f" ]] || continue
    grep -Eq "^[[:space:]]*(deb|URIs:).*$1" "$f" || continue
    tmp="$(mktemp)"
    if [[ "$f" == *.sources ]]; then
      RE="$1" awk 'BEGIN { RS = ""; ORS = "\n\n" } $0 !~ ("(^|\n)URIs:[^\n]*" ENVIRON["RE"])' "$f" > "$tmp"
    else
      RE="$1" awk '$0 !~ ("^[[:space:]]*deb.*" ENVIRON["RE"])' "$f" > "$tmp"
    fi
    if [[ "$f" == /etc/apt/sources.list ]] || grep -Eq '^[[:space:]]*(deb|URIs:)' "$tmp"; then
      sudo install -m 0644 "$tmp" "$f"
    else
      sudo rm -f "$f"
    fi
    rm -f "$tmp"
  done
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

if [[ "${EUID:-$(id -u)}" -eq 0 || -n "${SUDO_USER:-}" ]]; then
  err "Run this script without sudo. It configures VSCodium for your user and calls sudo itself."
  exit 1
fi

# Skip if already installed
log "Checking if VSCodium is already installed..."
if pkg_installed codium || command -v codium >/dev/null 2>&1; then
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
if [[ -s "$KEYRING" ]]; then
  log "Using existing keyring: $KEYRING"
else
  log "Downloading VSCodium key and writing to $KEYRING"
  # Dearmor to a temp file first; a failed download never leaves a partial keyring behind.
  TMP_KEY="$(mktemp)"
  trap 'rm -f "$TMP_KEY"' EXIT
  curl -fsSL "$KEY_URL" | gpg --dearmor > "$TMP_KEY"
  sudo install -m 0644 "$TMP_KEY" "$KEYRING"
fi

log "Cleaning duplicate VSCodium APT sources..."
remove_apt_entries 'download[.]vscodium[.]com'

log "Adding VSCodium APT repository..."
printf 'Types: deb\nURIs: https://download.vscodium.com/debs\nSuites: vscodium\nComponents: main\nArchitectures: %s\nSigned-By: %s\n' "$ARCH" "$KEYRING" | sudo tee "$SOURCES" >/dev/null
sudo chmod 0644 "$SOURCES"

log "Updating package lists..."
sudo apt-get update

log "Installing codium..."
sudo apt-get install -y codium

# Only without existing settings: they survive a package removal and must not be replaced by a reinstall.
CONFIGURE_CODIUM="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/codium/configure_codium.sh"
if [[ -f "$HOME/.config/VSCodium/User/settings.json" ]]; then
  log "Existing VSCodium settings kept. To apply the stored ones: bash $CONFIGURE_CODIUM"
elif [[ -f "$CONFIGURE_CODIUM" ]]; then
  log "Applying VSCodium settings..."
  if ! bash "$CONFIGURE_CODIUM"; then
    log "Warning: VSCodium settings not fully applied. Re-run: bash $CONFIGURE_CODIUM"
  fi
else
  log "Warning: $CONFIGURE_CODIUM not found; VSCodium settings not applied."
fi

log "VSCodium installation complete."
log "Launch: codium"
