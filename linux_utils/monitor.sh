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
  title "Refreshing tmux monitor window"
  if tmux list-windows -F '#{window_name}' | grep -qx 'monitor'; then
    tmux kill-window -t :monitor || true
  fi
  tmux new-window -n monitor 'top'
  tmux split-window -h -t :monitor "watch -n ${INTERVAL} -d sensors"
  tmux select-layout -t :monitor even-horizontal
  tmux select-window -t :monitor
else
  title "Starting tmux monitor session"
  if tmux has-session -t monitor 2>/dev/null; then
    tmux attach -t monitor
  else
    tmux new-session -d -s monitor -n monitor 'top'
    tmux split-window -h -t monitor:monitor "watch -n ${INTERVAL} -d sensors"
    tmux select-layout -t monitor:monitor even-horizontal
    tmux attach -t monitor
  fi
fi
