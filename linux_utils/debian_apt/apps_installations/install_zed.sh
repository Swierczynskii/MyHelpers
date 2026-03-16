#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_zed.sh
# Install Zed via the official installer script from zed.dev.
# Prerequisites: sudo (optional for wget bootstrap), apt-get, curl or wget, network access
# Usage: ./install_zed.sh
# Optional env:
#   ZED_CHANNEL=stable|preview|nightly|dev   (default: stable)
#   ZED_VERSION=latest|<version>             (default: latest)
#   FORCE_REINSTALL=1                        (default: 0; reinstall even if present)
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

warn() {
  print_box "WARNING\n$*" "$TITLE_COLOR"
}

err() {
  print_box "ERROR\n$*" "$ERROR_COLOR" >&2
}

title() {
  print_box "$*" "$TITLE_COLOR"
}

if [[ "${SKIP_INSTALLER_TITLE:-0}" != "1" ]]; then
  title "Installing Zed"
fi

# Keep backend consistency with this folder.
if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Zed installer writes to ~/.local, so running as root installs for root only.
if (( EUID == 0 )); then
  err "Do not run this script as root. Run it as your regular user."
  exit 1
fi

FORCE_REINSTALL="${FORCE_REINSTALL:-0}"
ZED_CHANNEL="${ZED_CHANNEL:-stable}"
ZED_VERSION="${ZED_VERSION:-latest}"

case "$ZED_CHANNEL" in
  stable|preview|nightly|dev) ;;
  *)
    err "Invalid ZED_CHANNEL='$ZED_CHANNEL'. Allowed: stable|preview|nightly|dev"
    exit 1
    ;;
esac

if [[ "$FORCE_REINSTALL" != "1" ]]; then
  log "Checking if Zed is already installed..."
  if command -v zed >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/zed" ]]; then
    log "zed already installed. Skipping."
    log "To reinstall/upgrade via this script, run with FORCE_REINSTALL=1."
    exit 0
  fi
fi

log "Ensuring prerequisites..."
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  log "Installing wget (no curl/wget found)"
  sudo apt-get update
  sudo apt-get install -y wget
fi

log "Installing Zed via official installer..."
log "Channel: $ZED_CHANNEL"
log "Version: $ZED_VERSION"
if command -v curl >/dev/null 2>&1; then
  curl -f https://zed.dev/install.sh | ZED_CHANNEL="$ZED_CHANNEL" ZED_VERSION="$ZED_VERSION" sh
else
  wget -qO- https://zed.dev/install.sh | ZED_CHANNEL="$ZED_CHANNEL" ZED_VERSION="$ZED_VERSION" sh
fi

log "Verifying installation..."
if command -v zed >/dev/null 2>&1; then
  log "zed available in PATH: $(command -v zed)"
elif [[ -x "$HOME/.local/bin/zed" ]]; then
  log "zed installed at: $HOME/.local/bin/zed"
  log "Add ~/.local/bin to PATH to run 'zed' directly."
else
  err "Zed installation completed but 'zed' binary was not found."
  exit 1
fi

log "Zed installation complete."
log "Launch: zed"
