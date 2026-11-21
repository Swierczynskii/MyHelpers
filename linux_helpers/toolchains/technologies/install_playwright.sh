#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install the Playwright CLI globally via npm and download browsers.
# Usable standalone (bash technologies/install_playwright.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_playwright() {
  if ! have npm; then
    warn "npm not found; skipping Playwright installation."
    return
  fi

  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  ensure_path_entry "export PATH=\"\$HOME/.local/bin:\$PATH\""

  if have playwright; then
    log "Playwright already installed: $(playwright --version 2>/dev/null || echo 'present')"
    return
  fi

  log "Installing Playwright globally via npm..."
  npm install -g --prefix "$HOME/.local" @playwright/test
  hash -r || true

  if ! have playwright; then
    warn "Playwright CLI was installed, but 'playwright' is not visible in PATH in this shell yet."
    return
  fi

  if (( SYSTEM_MODE )); then
    log "Installing Playwright browsers and system dependencies..."
    playwright install --with-deps chromium firefox webkit
  else
    log "Installing Playwright browsers for this user..."
    playwright install chromium firefox webkit
  fi
  log "Playwright installed: $(playwright --version || true)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_playwright
fi
