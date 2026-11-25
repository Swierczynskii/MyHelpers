#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_helpers/debian_apt/apps_installations/install_keepassxc.sh
# Install KeePassXC via apt-get (official PPA on Ubuntu, distro repo otherwise)
# Prerequisites: sudo, apt-get, network access
# Usage: ./install_keepassxc.sh
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

err() {
  print_box "ERROR\n$*" "$ERROR_COLOR" >&2
}

title() {
  print_box "$*" "$TITLE_COLOR"
}

if [[ "${SKIP_INSTALLER_TITLE:-0}" != "1" ]]; then
  title "Installing KeePassXC"
fi

# Ubuntu-based: official KeePassXC PPA (tracks upstream releases).
# Debian / unsupported release: distro package (may lag behind upstream).
PPA='ppa:phoerious/keepassxc'
PPA_URL='https://ppa.launchpadcontent.net/phoerious/keepassxc/ubuntu'

# Ensure apt is available
if ! command -v apt-get >/dev/null 2>&1; then
  err "apt-get not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Non-apt install (snap, AppImage, ...) already on PATH: leave it alone.
if ! pkg_installed keepassxc && ! pkg_installed keepassxc-full \
  && command -v keepassxc >/dev/null 2>&1; then
  log "Non-apt KeePassXC found at $(command -v keepassxc). Skipping."
  exit 0
fi

has_ppa() {
  grep -rqs 'phoerious/keepassxc' /etc/apt/sources.list /etc/apt/sources.list.d/
}

ppa_supports_release() {
  local url="${PPA_URL}/dists/$1/Release"
  if command -v curl >/dev/null 2>&1; then
    curl -fsI "$url" >/dev/null
  else
    wget -q --spider "$url"
  fi
}

# shellcheck disable=SC1091
. /etc/os-release
CODENAME="${UBUNTU_CODENAME:-}"

if [[ -n "$CODENAME" ]] && { has_ppa || ppa_supports_release "$CODENAME"; }; then
  if has_ppa; then
    log "KeePassXC PPA already configured. Updating package lists..."
    sudo apt-get update
  else
    log "Adding official KeePassXC PPA ($PPA) for $CODENAME..."
    if ! command -v add-apt-repository >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y software-properties-common
    fi
    # Imports the signing key into a signed-by .sources entry and runs apt-get update.
    sudo add-apt-repository -y "$PPA"
  fi

  # The PPA ships everything in `keepassxc`; Ubuntu's `keepassxc-full` owns the same
  # files, so swap it out in one transaction. Settings and .kdbx files are untouched.
  if pkg_installed keepassxc-full; then
    log "Replacing Ubuntu's keepassxc-full with the PPA build..."
    sudo apt-get install -y keepassxc keepassxc-full-
  else
    log "Installing/upgrading KeePassXC from the PPA..."
    sudo apt-get install -y keepassxc
  fi
else
  if pkg_installed keepassxc; then
    log "keepassxc already installed (distro package). Skipping."
    exit 0
  fi
  log "KeePassXC PPA not available for this system; using distro package (may lag upstream)."
  sudo apt-get update
  sudo apt-get install -y keepassxc
fi

log "KeePassXC installation complete: $(dpkg-query -W -f='${Version}' keepassxc)"
log "Launch: keepassxc"
