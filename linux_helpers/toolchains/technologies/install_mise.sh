#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install mise (tool version manager) from its signed APT repository and activate it in shell rc files.
# Usable standalone (bash technologies/install_mise.sh) or sourced by bootstrap_toolchains.sh (--system).

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MISE_KEY_URL='https://mise.jdx.dev/gpg-key.pub'
# Pinned "mise releases <release@mise.jdx.dev>" key; update only after verifying a rotation upstream.
MISE_KEY_FINGERPRINT='24853EC9F655CE80B48E6C3A8B81C9D17413A06D'
MISE_KEYRING='/etc/apt/keyrings/mise-archive-keyring.gpg'
MISE_LIST='/etc/apt/sources.list.d/mise.list'

activate_mise() {
  local shell rc
  for shell in bash zsh; do
    rc="$HOME/.${shell}rc"
    # Respect any existing activation (hand-written or tool-managed) instead of adding a second one.
    if grep -qs 'mise activate' "$rc"; then
      continue
    fi
    append_unique_line "$rc" "if command -v mise >/dev/null 2>&1; then eval \"\$(mise activate ${shell})\"; fi"
  done
}

install_mise() {
  if have mise; then
    log "mise already installed: $(mise --version 2>/dev/null || echo 'present')"
    activate_mise
    return
  fi

  require_sudo
  local arch
  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64|arm64) ;;
    *)
      warn "The mise APT repository has no ${arch} packages; skipping mise installation."
      return
      ;;
  esac

  if [[ -f "$MISE_KEYRING" ]]; then
    log "Using existing keyring: $MISE_KEYRING"
  else
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    log "Downloading mise signing key and verifying its fingerprint..."
    curl -fsSL "$MISE_KEY_URL" -o "$tmp/key.pub"
    local key_info primary_count fingerprint
    key_info="$(gpg --show-keys --with-colons "$tmp/key.pub" 2>/dev/null || true)"
    primary_count="$(grep -c '^pub:' <<< "$key_info" || true)"
    fingerprint="$(awk -F: '/^fpr:/ { print $10; exit }' <<< "$key_info")"
    # Exactly one primary key, and it must be the pinned one (an extra key would also be trusted by apt).
    if [[ "$primary_count" != "1" || "$fingerprint" != "$MISE_KEY_FINGERPRINT" ]]; then
      err "mise signing key verification failed (keys: ${primary_count:-0}, fingerprint: ${fingerprint:-none}); refusing to add the repository."
      exit 1
    fi

    gpg --dearmor < "$tmp/key.pub" > "$tmp/mise-archive-keyring.gpg"
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo install -m 0644 "$tmp/mise-archive-keyring.gpg" "$MISE_KEYRING"
  fi

  log "Adding mise APT repository..."
  printf 'deb [arch=%s signed-by=%s] https://mise.jdx.dev/deb stable main\n' "$arch" "$MISE_KEYRING" | sudo tee "$MISE_LIST" >/dev/null
  sudo chmod 0644 "$MISE_LIST"

  log "Installing mise via apt..."
  sudo apt-get update
  sudo apt-get install -y mise
  hash -r || true

  activate_mise
  log "mise installed: $(mise --version 2>/dev/null || echo 'present'). Open a new shell to activate it."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_mise
fi
