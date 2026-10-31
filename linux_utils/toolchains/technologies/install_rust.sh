#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install Rust with rustup into ~/.cargo/bin.
# Usable standalone (bash technologies/install_rust.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_rust() {
  if have cargo && have rustc; then
    log "Rust already installed: $(rustc --version 2>/dev/null || echo 'present')"
    ensure_path_entry "export PATH=\"\$HOME/.cargo/bin:\$PATH\""
    export PATH="$HOME/.cargo/bin:$PATH"
    return
  fi

  log "Installing Rust with rustup..."
  local rustup_url="${RUSTUP_INIT_URL:-https://sh.rustup.rs}"
  local rustup_sha256_expected="${RUSTUP_INIT_SHA256:-}"
  local tmp_rustup
  tmp_rustup="$(mktemp)"
  trap 'rm -f "$tmp_rustup"' RETURN

  if ! curl -fsSL "$rustup_url" -o "$tmp_rustup"; then
    err "Failed to download rustup installer from $rustup_url"
    exit 1
  fi

  if [[ -n "$rustup_sha256_expected" ]]; then
    local rustup_sha256_actual
    rustup_sha256_actual="$(sha256sum "$tmp_rustup" | awk '{print $1}')"
    if [[ "$rustup_sha256_actual" != "$rustup_sha256_expected" ]]; then
      err "rustup installer SHA256 mismatch. Expected: $rustup_sha256_expected, Got: $rustup_sha256_actual"
      exit 1
    fi
    log "rustup installer SHA256 verified."
  else
    warn "RUSTUP_INIT_SHA256 not set; proceeding without installer hash verification."
  fi

  sh "$tmp_rustup" -y --no-modify-path

  ensure_path_entry "export PATH=\"\$HOME/.cargo/bin:\$PATH\""
  export PATH="$HOME/.cargo/bin:$PATH"

  if have rustc; then
    log "Rust installed: $(rustc --version || true)"
  else
    warn "Rust install completed, but rustc is not on PATH until a new shell is opened."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_rust
fi
