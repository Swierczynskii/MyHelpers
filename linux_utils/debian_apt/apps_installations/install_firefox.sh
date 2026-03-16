#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_firefox.sh
# Install Firefox via official Mozilla APT repository (keyrings + signed-by)
# Prerequisites: sudo, apt-get, curl or wget, network access, optional snap
# Usage: ./install_firefox.sh
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
  title "Installing Firefox"
fi

# Firefox installation via official Mozilla APT repository (keyrings + signed-by)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

log "Ensuring prerequisites..."
NEED_UPDATE=0
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  log "Installing wget (no curl/wget found)"
  sudo apt-get update
  sudo apt-get install -y wget
  NEED_UPDATE=1
fi

# Special handling for Firefox:
# - If Snap Firefox exists, remove it first
# - If APT Firefox already installed, skip installation
log "Checking for Snap Firefox..."
if command -v snap >/dev/null 2>&1; then
  if snap list firefox >/dev/null 2>&1; then
    log "Found Firefox installed via Snap. Removing..."
    if ! sudo snap remove --purge firefox; then
      log "Purge failed; attempting regular remove..."
      sudo snap remove firefox || { err "Unable to remove Snap Firefox."; exit 1; }
    fi
    log "Removed Snap Firefox."
  else
    log "Snap Firefox not present."
  fi
else
  log "snap not found; skipping snap check."
fi

log "Checking if Firefox (APT) is already installed..."
if dpkg -s firefox >/dev/null 2>&1; then
  log "Firefox (APT) already installed. Skipping."
  exit 0
fi

log "Preparing keyrings directory..."
sudo install -d -m 0755 /etc/apt/keyrings

KEYRING="/etc/apt/keyrings/packages.mozilla.org.asc"
LIST="/etc/apt/sources.list.d/mozilla.list"
PREF="/etc/apt/preferences.d/mozilla"

log "Installing Mozilla signing key..."
if [[ ! -f "$KEYRING" ]]; then
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo tee "$KEYRING" >/dev/null
  else
    wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo tee "$KEYRING" >/dev/null
  fi
  sudo chmod 0644 "$KEYRING"
else
  log "Keyring already exists: $KEYRING"
fi

log "Adding Mozilla APT repository..."
if [[ ! -f "$LIST" ]]; then
  echo "deb [signed-by=$KEYRING] https://packages.mozilla.org/apt mozilla main" | sudo tee "$LIST" >/dev/null
else
  log "Repository list already exists: $LIST"
fi

log "Setting APT pinning to prefer Mozilla origin..."
if [[ ! -f "$PREF" ]]; then
  sudo tee "$PREF" >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
else
  log "Preferences already exist: $PREF"
fi

log "Updating package lists..."
sudo apt-get update

log "Installing firefox..."
sudo apt-get install -y firefox

log "Firefox installation complete."
log "Launch: firefox"
