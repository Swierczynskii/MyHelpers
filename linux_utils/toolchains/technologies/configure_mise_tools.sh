#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install the global developer toolchains with mise (verified downloads, one config file).
# Global defaults live in ~/.config/mise/config.toml; a repo's own mise.toml overrides them.
# Python versions are managed by uv, so Python is intentionally not listed here.
# Usable standalone (bash technologies/configure_mise_tools.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# node@lts follows each new LTS line automatically (mise upgrade moves to it).
MISE_GLOBAL_TOOLS=(node@lts pnpm@latest go@latest rust@stable bun@latest uv@latest sqlite3def@latest)

configure_mise_tools() {
  if ! have mise; then
    err "mise not found. Run bootstrap_toolchains.sh --system (installs mise from its signed APT repo) and rerun."
    exit 1
  fi

  # Interactive shells use 'mise activate' (install_mise.sh); login files get the shims so
  # non-interactive shells, scripts, and GUI apps (e.g. editors started from the launcher) see the tools too.
  local shims_line="export PATH=\"\$HOME/.local/share/mise/shims:\$PATH\""
  local profile
  for profile in "$HOME/.profile" "$HOME/.bash_profile"; do
    if [[ "$profile" == "$HOME/.profile" || -f "$profile" ]]; then
      append_unique_line "$profile" "$shims_line"
    fi
  done
  export PATH="$HOME/.local/share/mise/shims:$PATH"

  log "Installing global tools with mise: ${MISE_GLOBAL_TOOLS[*]}"
  mise use --global "${MISE_GLOBAL_TOOLS[@]}"
  hash -r || true

  log "Global mise tools:"
  mise ls --global --current || true
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  configure_mise_tools
fi
