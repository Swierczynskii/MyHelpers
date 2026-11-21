#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install Podman and extras via apt.
# Usable standalone (bash technologies/install_podman.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_podman() {
  require_sudo
  if have podman || dpkg -s podman >/dev/null 2>&1; then
    log "podman already installed: $(podman --version 2>/dev/null || echo 'present')"
    return
  fi

  local pkgs=("podman")
  local extras=(uidmap slirp4netns fuse-overlayfs netavark aardvark-dns podman-docker)
  local x
  for x in "${extras[@]}"; do
    if apt_pkg_available "$x"; then
      pkgs+=("$x")
    fi
  done

  if ! apt_pkg_available netavark && apt_pkg_available containernetworking-plugins; then
    pkgs+=("containernetworking-plugins")
  fi

  log "Installing Podman and extras via apt: ${pkgs[*]}"
  sudo apt-get install -y "${pkgs[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_podman
fi
