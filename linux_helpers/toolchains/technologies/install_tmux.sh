#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install tmux via apt.
# Usable standalone (bash technologies/install_tmux.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_tmux() {
  require_sudo
  if have tmux; then
    log "tmux already installed: $(tmux -V || true)"
  else
    log "Installing tmux via apt..."
    sudo apt-get install -y tmux
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_tmux
fi
