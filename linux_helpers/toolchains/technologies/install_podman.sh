#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install Podman and extras via apt.
# Usable standalone (bash technologies/install_podman.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

warn_docker_replacement() {
  local found=()
  local pkg
  # Packages that podman-docker conflicts with.
  for pkg in docker.io docker-cli docker-ce-cli; do
    if pkg_installed "$pkg"; then
      found+=("$pkg")
    fi
  done

  if (( ${#found[@]} )); then
    warn "Installed Docker packages conflict with podman-docker: ${found[*]}\nPodman replaces them: apt will remove them and any packages that depend on them."
  fi
}

install_podman() {
  require_sudo
  if have podman || pkg_installed podman; then
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

  if [[ " ${pkgs[*]} " == *" podman-docker "* ]]; then
    warn_docker_replacement
  fi

  log "Installing Podman and extras via apt: ${pkgs[*]}"
  sudo apt-get install -y "${pkgs[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_podman
fi
