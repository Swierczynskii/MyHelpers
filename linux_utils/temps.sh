#!/usr/bin/env bash
set -euo pipefail
# -----------------------------------------------------------------------------
# linux_utils/temps.sh
# Simple temperature monitor wrapper
#
# Prerequisites:
# - lm-sensors (provides 'sensors')
# - watch (procps/procps-ng)
#
# Usage:
#   ./temps.sh
#   INTERVAL=2 ./temps.sh   # refresh every 2 seconds (default: 1)
#
# Description:
#   Runs 'watch -n <interval> -d sensors' to refresh periodically with diffs highlighted.
#   The script exits with an error if required commands are missing.
# -----------------------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

if ! have sensors; then
  echo "ERROR: 'sensors' not found. Install 'lm-sensors' (apt: sudo apt install lm-sensors; dnf: sudo dnf install lm_sensors)." >&2
  exit 1
fi

if ! have watch; then
  echo "ERROR: 'watch' not found. Install 'procps' (Debian/Ubuntu) or 'procps-ng' (Fedora)." >&2
  exit 1
fi

INTERVAL="${INTERVAL:-1}"
exec watch -n "$INTERVAL" -d sensors
