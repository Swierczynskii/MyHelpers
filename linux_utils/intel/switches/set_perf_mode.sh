#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/intel/switches/set_perf_mode.sh
# Switch to Intel 'best performance' tuned profile.
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

switch_tuned_profile 'intel-best_performance_mode'
