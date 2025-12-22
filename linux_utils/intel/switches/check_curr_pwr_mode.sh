#!/usr/bin/env bash
set -euo pipefail
# -----------------------------------------------------------------------------
# linux_utils/intel/switches/check_curr_pwr_mode.sh
# Show the currently active tuned profile.
#
# Prerequisites:
# - tuned-adm (from tuned)
# - Intel EPP profiles installed if you plan to switch to Intel-specific modes
#
# Usage:
#   ./check_curr_pwr_mode.sh
# -----------------------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

if ! have tuned-adm; then
  echo "ERROR: 'tuned-adm' not found. Install 'tuned' package." >&2
  exit 1
fi

echo "[*] Current tuned profile:"
tuned-adm active