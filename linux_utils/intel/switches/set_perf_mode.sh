#!/usr/bin/env bash
set -euo pipefail
# -----------------------------------------------------------------------------
# linux_utils/intel/switches/set_perf_mode.sh
# Switch to Intel "best performance" tuned profile.
#
# Prerequisites:
# - tuned-adm (from tuned)
# - Intel EPP profiles available (intel-best_performance_mode)
#
# Usage:
#   sudo ./set_perf_mode.sh
#
# Notes:
# - Typically requires root privileges; run via sudo if permission is denied.
# - Shows current profile, applies requested profile, then shows active profile.
# -----------------------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

if ! have tuned-adm; then
  echo "ERROR: 'tuned-adm' not found. Install the 'tuned' package." >&2
  exit 1
fi

PROFILE="intel-best_performance_mode"

echo "[*] Current tuned profile (before):"
tuned-adm active || true

echo "[*] Switching to profile: ${PROFILE} ..."
if ! tuned-adm profile "${PROFILE}"; then
  echo "ERROR: Failed to apply profile '${PROFILE}'. You may need to run this script with sudo." >&2
  exit 1
fi

echo "[*] Current tuned profile (after):"
tuned-adm active