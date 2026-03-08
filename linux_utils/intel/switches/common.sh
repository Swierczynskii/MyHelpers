COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
fi

TIMESTAMP_COLOR='\033[1;36m'
ERROR_COLOR='\033[1;31m'
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

have() { command -v "$1" >/dev/null 2>&1; }

require_tuned_adm() {
  if ! have tuned-adm; then
    err "'tuned-adm' not found. Install the 'tuned' package."
    exit 1
  fi
}

show_current_tuned_profile() {
  local message="$1"
  require_tuned_adm
  log "$message"
  tuned-adm active
}

switch_tuned_profile() {
  local profile="$1"

  require_tuned_adm
  log 'Current tuned profile (before):'
  tuned-adm active || true

  log "Switching to profile: ${profile} ..."
  if ! tuned-adm profile "$profile"; then
    err "Failed to apply profile '${profile}'. You may need to run this script with sudo."
    exit 1
  fi

  log 'Current tuned profile (after):'
  tuned-adm active
}
