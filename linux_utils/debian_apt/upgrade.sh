#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/upgrade.sh
# Non-interactive APT upgrade helper for Debian/Ubuntu.
# Performs: update, upgrade -y, autoremove -y.
# -----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
fi

TIMESTAMP_COLOR='\033[1;36m'
ERROR_COLOR='\033[1;31m'
TITLE_COLOR='\033[1;33m'
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

title 'Starting system upgrade'

log 'Running apt-get update...'
if ! sudo apt-get update; then
  err 'apt-get update failed.'
  exit 1
fi

log 'Running apt-get upgrade -y...'
if ! sudo apt-get upgrade -y; then
  err 'apt-get upgrade failed.'
  exit 1
fi

log 'Running apt-get autoremove -y...'
if ! sudo apt-get autoremove -y; then
  err 'apt-get autoremove failed.'
  exit 1
fi

log 'System upgrade completed successfully.'
