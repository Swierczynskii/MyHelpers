#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install uv (Astral official installer) into ~/.local/bin.
# Usable standalone (bash technologies/install_uv.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_uv() {
  if have uv; then
    log "uv already installed: $(uv --version || true)"
    return
  fi

  log "Installing uv (Astral) with staged download..."
  local UV_URL="${UV_INSTALL_URL:-https://astral.sh/uv/install.sh}"
  local UV_SHA256_EXPECTED="${UV_INSTALL_SHA256:-}"
  local tmp_uv
  tmp_uv="$(mktemp)"
  trap 'rm -f "$tmp_uv"' RETURN

  if ! curl -fsSL "$UV_URL" -o "$tmp_uv"; then
    err "Failed to download uv installer from $UV_URL"
    exit 1
  fi

  if [[ -n "$UV_SHA256_EXPECTED" ]]; then
    local UV_SHA256_ACTUAL
    UV_SHA256_ACTUAL="$(sha256sum "$tmp_uv" | awk '{print $1}')"
    if [[ "$UV_SHA256_ACTUAL" != "$UV_SHA256_EXPECTED" ]]; then
      err "uv installer SHA256 mismatch. Expected: $UV_SHA256_EXPECTED, Got: $UV_SHA256_ACTUAL"
      exit 1
    fi
    log "uv installer SHA256 verified."
  else
    warn "UV_INSTALL_SHA256 not set; proceeding without installer hash verification."
  fi

  sh "$tmp_uv"

  # Ensure ~/.local/bin on PATH
  ensure_path_entry "export PATH=\"\$HOME/.local/bin:\$PATH\""
  export PATH="$HOME/.local/bin:$PATH"
  log "uv installed: $(uv --version || true)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_uv
fi
