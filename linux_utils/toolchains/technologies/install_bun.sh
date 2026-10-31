#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install Bun with the official installer into ~/.local/bun.
# Usable standalone (bash technologies/install_bun.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_bun() {
  local bun_install="$HOME/.local/bun"

  ensure_path_entry "export BUN_INSTALL=\"\$HOME/.local/bun\""
  ensure_path_entry "export PATH=\"\$BUN_INSTALL/bin:\$PATH\""
  export BUN_INSTALL="$bun_install"
  export PATH="$BUN_INSTALL/bin:$PATH"

  if have bun; then
    log "Bun already installed: $(bun --version 2>/dev/null || echo 'present')"
    return
  fi

  local tmp_bun
  tmp_bun="$(mktemp)"
  trap 'rm -f "$tmp_bun"' RETURN

  log "Installing Bun with staged official installer..."
  if ! curl -fsSL 'https://bun.com/install' -o "$tmp_bun"; then
    err 'Failed to download the Bun installer.'
    exit 1
  fi

  # The installer normally edits one shell profile. Use an unsupported shell
  # here, then manage PATH entries ourselves with ensure_path_entry above.
  SHELL=/bin/false BUN_INSTALL="$bun_install" bash "$tmp_bun"
  hash -r || true

  if have bun; then
    log "Bun installed: $(bun --version || true)"
  else
    warn "Bun installation completed, but bun is not visible in PATH. Open a new shell and try again."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_bun
fi
