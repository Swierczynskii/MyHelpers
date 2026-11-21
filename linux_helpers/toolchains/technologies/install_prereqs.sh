#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install apt prerequisites (requires --system / MYHELPERS_SYSTEM=1 context).
# Usable standalone (bash technologies/install_prereqs.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_prereqs() {
  require_sudo
  if ! have apt-get; then
    err "apt-get is required for --system package installation."
    exit 1
  fi
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -y
  sudo apt-get install -y \
    ca-certificates curl wget git unzip tar xz-utils gnupg \
    build-essential pkg-config make gcc
  log "git present: $(git --version 2>/dev/null || true)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_prereqs
fi
