#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install the Scala toolchain with Coursier (cs, installed by mise): scala, scalac, sbt, scalafmt, metals.
# Coursier downloads its own JVM on demand, so no system Java is needed.
# Usable standalone (bash technologies/install_scala.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SCALA_APPS=(scala scalac sbt scalafmt metals)

install_scala() {
  if ! have cs; then
    warn "cs (coursier) not found; run configure_mise_tools.sh first. Skipping Scala."
    return
  fi

  local bin="$HOME/.local/share/coursier/bin"
  export PATH="$bin:$PATH"
  ensure_path_entry "export PATH=\"$bin:\$PATH\""

  local app
  for app in "${SCALA_APPS[@]}"; do
    if [[ -x "$bin/$app" ]]; then
      log "$app already installed"
    else
      log "Installing $app via coursier..."
      cs install "$app"
    fi
  done
  hash -r || true
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_scala
fi
