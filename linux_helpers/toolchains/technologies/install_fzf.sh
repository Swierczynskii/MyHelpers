#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install fzf via apt.
# Usable standalone (bash technologies/install_fzf.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_fzf() {
  require_sudo
  if have fzf || dpkg -s fzf >/dev/null 2>&1; then
    log "fzf already installed: $(fzf --version 2>/dev/null || echo 'present')"
  else
    log "Installing fzf via apt..."
    sudo apt-get install -y fzf
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_fzf
fi
