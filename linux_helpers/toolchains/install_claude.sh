#!/usr/bin/env bash
set -euo pipefail
umask 022

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1" >&2; }

STATUSLINE_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/claude_statusline.sh"

configure_statusline() {
  local target="$HOME/.claude/statusline-command.sh"
  local settings="$HOME/.claude/settings.json"
  # shellcheck disable=SC2088
  local cmd='bash ~/.claude/statusline-command.sh'
  local current='' tmp_settings

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found; skipping Claude Code status line. Install jq and re-run."
    return 0
  fi
  if [[ ! -f "$STATUSLINE_SOURCE" ]]; then
    warn "Status line script not found at $STATUSLINE_SOURCE; skipping."
    return 0
  fi

  if [[ -s "$settings" ]]; then
    if ! current="$(jq -r 'if .statusLine == null then "" else .statusLine.command // "custom" end' "$settings" 2>/dev/null)"; then
      warn "Could not parse $settings; skipping status line."
      return 0
    fi
  fi
  if [[ -n "$current" && "$current" != "$cmd" ]]; then
    info "Keeping the existing custom Claude Code status line."
    return 0
  fi
  if [[ -f "$target" ]] && ! grep -Fq 'derived from the MyHelpers PS1' "$target"; then
    warn "$target was not created by MyHelpers; leaving the status line untouched."
    return 0
  fi

  mkdir -p "$HOME/.claude"
  if ! cmp -s "$STATUSLINE_SOURCE" "$target"; then
    cp "$STATUSLINE_SOURCE" "$target"
  fi
  if [[ -z "$current" ]]; then
    # Missing, empty or whitespace-only: jq would print nothing.
    grep -qs '[^[:space:]]' "$settings" || echo '{}' > "$settings"
    tmp_settings="$(mktemp)"
    jq --arg cmd "$cmd" '.statusLine = {type: "command", command: $cmd}' "$settings" > "$tmp_settings"
    # Write in place to keep the file's permissions and any symlink.
    cat "$tmp_settings" > "$settings"
    rm -f "$tmp_settings"
  fi
  info "Claude Code status line configured."
}

case "${1:-}" in
  "") ;;
  -h|--help)
    echo "Usage: bash linux_helpers/toolchains/install_claude.sh"
    echo "Installs Claude Code with Anthropic's native installer (skips if present)."
    echo "Also sets up the status line in ~/.claude (an existing custom one is kept)."
    exit 0
    ;;
  *)
    error "Unknown option: $1"
    exit 1
    ;;
esac

if [[ "${EUID:-$(id -u)}" -eq 0 || -n "${SUDO_USER:-}" ]]; then
  error "Run this script without sudo so Claude Code is installed for your user."
  exit 1
fi

echo ""
echo "=== Claude Code installation ==="

# The native installer puts claude here; this shell may not have it on PATH yet.
export PATH="$HOME/.local/bin:$PATH"

if command -v claude >/dev/null 2>&1; then
  info "Claude Code is already installed."
  configure_statusline
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  error "Required command not found: curl"
  exit 1
fi

info "Installing Claude Code with Anthropic native installer..."
# Stage the installer so a dropped connection can't execute a truncated script.
tmp_installer="$(mktemp)"
trap 'rm -f "$tmp_installer"' EXIT
curl -fsSL https://claude.ai/install.sh -o "$tmp_installer"
# The installer uses bash syntax; plain sh is dash on Debian/Ubuntu and fails to parse it.
bash "$tmp_installer"
hash -r || true

if command -v claude >/dev/null 2>&1; then
  info "Claude Code installed successfully."
else
  warn "Claude Code was installed, but 'claude' is not visible in PATH in this shell yet."
fi

configure_statusline
