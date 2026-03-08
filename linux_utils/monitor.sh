#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/monitor.sh
# Tmux-based system monitor: side-by-side 'top' and 'watch -n <interval> -d sensors'.
# Accepts fractional INTERVAL values such as 0.5 or .5.
# -----------------------------------------------------------------------------

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

warn() {
  printf '%s WARNING: %s\n' "$(timestamp)" "$*"
}

err() {
  if (( COLOR_ENABLED )); then
    printf '%s %bERROR:%b %s\n' "$(timestamp)" "$ERROR_COLOR" "$NC" "$*" >&2
  else
    printf '%s ERROR: %s\n' "$(timestamp)" "$*" >&2
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

if ! have tmux; then
  err "'tmux' not found. Run the toolchain bootstrap or install tmux."
  exit 1
fi
if ! have sensors; then
  err "'sensors' not found. Install 'lm-sensors' (apt: sudo apt install lm-sensors)."
  exit 1
fi
if ! have watch; then
  err "'watch' not found. Install 'procps' (apt: sudo apt install procps)."
  exit 1
fi
if ! have top; then
  err "'top' not found. Install 'procps' (apt: sudo apt install procps)."
  exit 1
fi

INTERVAL="${INTERVAL:-1}"
if [[ ! "$INTERVAL" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]; then
  warn "Invalid INTERVAL '$INTERVAL'; defaulting to 1"
  INTERVAL='1'
fi

if [[ -n "${TMUX:-}" ]]; then
  log "Refreshing tmux monitor window."
  if tmux list-windows -F '#{window_name}' | grep -qx 'monitor'; then
    tmux kill-window -t :monitor || true
  fi
  tmux new-window -n monitor 'top'
  tmux split-window -h -t :monitor "watch -n ${INTERVAL} -d sensors"
  tmux select-layout -t :monitor even-horizontal
  tmux select-window -t :monitor
else
  log "Starting tmux monitor session."
  if tmux has-session -t monitor 2>/dev/null; then
    tmux attach -t monitor
  else
    tmux new-session -d -s monitor -n monitor 'top'
    tmux split-window -h -t monitor:monitor "watch -n ${INTERVAL} -d sensors"
    tmux select-layout -t monitor:monitor even-horizontal
    tmux attach -t monitor
  fi
fi
