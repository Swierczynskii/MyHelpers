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

case "${1:-}" in
  "") ;;
  -h|--help)
    echo "Usage: bash linux_utils/toolchains/install_claude.sh"
    echo "Installs Claude Code with Anthropic's native installer (skips if present)."
    exit 0
    ;;
  *)
    error "Unknown option: $1"
    exit 1
    ;;
esac

if [[ -n "${SUDO_USER:-}" ]]; then
  error "Run this script without sudo so Claude Code is installed for your user."
  exit 1
fi

echo ""
echo "=== Claude Code installation ==="

if command -v claude >/dev/null 2>&1; then
  info "Claude Code is already installed."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  error "Required command not found: curl"
  exit 1
fi

info "Installing Claude Code with Anthropic native installer..."
curl -fsSL https://claude.ai/install.sh | sh
hash -r || true

if command -v claude >/dev/null 2>&1; then
  info "Claude Code installed successfully."
else
  warn "Claude Code was installed, but 'claude' is not visible in PATH in this shell yet."
fi
