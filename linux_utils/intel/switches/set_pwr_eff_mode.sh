#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/intel/switches/set_pwr_eff_mode.sh
# Switch to Intel 'best power efficiency' tuned profile.
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

switch_tuned_profile 'intel-best_power_efficiency_mode'
