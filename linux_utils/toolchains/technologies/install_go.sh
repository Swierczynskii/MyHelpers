#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install the latest stable Go from the official archive into ~/.local/go.
# Usable standalone (bash technologies/install_go.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_go() {
  local go_root="$HOME/.local/go"

  if [[ -x "$go_root/bin/go" ]]; then
    ensure_path_entry "export PATH=\"\$HOME/.local/go/bin:\$PATH\""
    export PATH="$go_root/bin:$PATH"
    log "Go already installed: $(go version 2>/dev/null || echo 'present')"
    return
  fi

  if have go; then
    log "Go already installed: $(go version 2>/dev/null || echo 'present')"
    return
  fi

  local version="${GO_VERSION:-}"
  if [[ -z "$version" ]]; then
    version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | awk 'NR == 1 { print; exit }')"
  fi
  if [[ -z "$version" ]]; then
    err "Unable to determine the latest stable Go version. Set GO_VERSION and rerun."
    exit 1
  fi
  if [[ "$version" != go* ]]; then
    version="go${version}"
  fi

  local arch
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      warn "Unsupported arch $(uname -m) for Go archive; skipping Go installation."
      return
      ;;
  esac

  local tarball="${version}.linux-${arch}.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  log "Downloading Go ${version#go} (linux-${arch}) and verifying checksum..."
  curl -fsSL 'https://go.dev/dl/?mode=json&include=all' -o "$tmp/releases.json"

  local checksum
  checksum="$(awk -v target="$tarball" '
    index($0, "\"filename\": \"" target "\"") { found = 1; next }
    found && /"sha256":/ {
      sub(/^.*"sha256": "/, "")
      sub(/".*$/, "")
      print
      exit
    }
  ' "$tmp/releases.json")"
  if [[ ! "$checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
    err "Unable to find an official checksum for ${tarball}."
    exit 1
  fi

  curl -fsSL "https://go.dev/dl/${tarball}" -o "$tmp/$tarball"
  printf '%s  %s\n' "$checksum" "$tmp/$tarball" | sha256sum -c - >/dev/null
  tar -C "$tmp" -xzf "$tmp/$tarball"

  local target="$HOME/.local/go-${version#go}"
  mkdir -p "$HOME/.local"
  rm -rf "$target"
  mv "$tmp/go" "$target"
  if [[ -e "$go_root" || -L "$go_root" ]]; then
    rm -rf "$go_root"
  fi
  ln -sfn "$target" "$go_root"

  ensure_path_entry "export PATH=\"\$HOME/.local/go/bin:\$PATH\""
  export PATH="$go_root/bin:$PATH"
  hash -r || true
  log "Go installed: $(go version || true)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_go
fi
