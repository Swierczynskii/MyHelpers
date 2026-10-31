#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install procps (top, watch) via apt.
# Usable standalone (bash technologies/install_top.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_top() {
  require_sudo
  if have top; then
    log "top already available: $(top -v 2>/dev/null | head -n1 || echo 'present')"
  else
    log "Installing procps (provides top, watch) via apt..."
    sudo apt-get install -y procps
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_top
fi
