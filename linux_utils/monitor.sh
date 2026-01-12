#!/usr/bin/env bash
set -euo pipefail
# -----------------------------------------------------------------------------
# linux_utils/monitor.sh
# Tmux-based system monitor: side-by-side 'top' and 'watch -n <interval> -d sensors'
#
# Replaces: linux_utils/temps.sh
#
# Prerequisites:
# - tmux
# - lm-sensors (provides 'sensors')
# - procps (provides 'top' and 'watch')
#
# Usage:
#   ./monitor.sh
#   INTERVAL=2 ./monitor.sh   # refresh every 2 seconds (default: 1)
# -----------------------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

if ! have tmux; then
  echo "ERROR: 'tmux' not found. Run the toolchain bootstrap or install tmux." >&2
  exit 1
fi
if ! have sensors; then
  echo "ERROR: 'sensors' not found. Install 'lm-sensors' (apt: sudo apt install lm-sensors)." >&2
  exit 1
fi
if ! have watch; then
  echo "ERROR: 'watch' not found. Install 'procps' (apt: sudo apt install procps)." >&2
  exit 1
fi
if ! have top; then
  echo "ERROR: 'top' not found. Install 'procps' (apt: sudo apt install procps)." >&2
  exit 1
fi

INTERVAL="${INTERVAL:-1}"
# Validate INTERVAL strictly numeric (integer or decimal)
if [[ ! "$INTERVAL" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "WARNING: Invalid INTERVAL '$INTERVAL'; defaulting to 1" >&2
  INTERVAL="1"
fi

# If inside an existing tmux session, create/refresh a 'monitor' window for monitoring.
# Otherwise, create/attach a dedicated 'monitor' session to keep a consistent name.
if [[ -n "${TMUX:-}" ]]; then
  # Inside an existing tmux session: create or replace a 'monitor' window
  if tmux list-windows -F "#{window_name}" | grep -qx "monitor"; then
    tmux kill-window -t :monitor || true
  fi
  tmux new-window -n monitor 'top'
  tmux split-window -h -t :monitor "watch -n ${INTERVAL} -d sensors"
  tmux select-layout -t :monitor even-horizontal
  tmux select-window -t :monitor
else
  # Outside tmux: start a dedicated 'monitor' session (reuse if exists)
  if tmux has-session -t monitor 2>/dev/null; then
    tmux attach -t monitor
  else
    tmux new-session -d -s monitor -n monitor 'top'
    tmux split-window -h -t monitor:monitor "watch -n ${INTERVAL} -d sensors"
    tmux select-layout -t monitor:monitor even-horizontal
    tmux attach -t monitor
  fi
fi