#!/usr/bin/env bash
set -euo pipefail
umask 022

RUN_CLAUDE=1
RUN_CODEX=1
RUN_ANTIGRAVITY=1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

info() {
  echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[!]${NC} $1"
}

error() {
  echo -e "${RED}[x]${NC} $1" >&2
}

usage() {
  cat <<'EOF'
Usage: bash ai/install_ai.sh [--claude] [--codex] [--antigravity]

Options:
  --claude       Install only Claude Code
  --codex        Install only Codex
  --antigravity  Install only Antigravity CLI
  -h, --help     Show this help message

Without options the script installs Claude Code, Codex, and Antigravity CLI.
EOF
}

parse_args() {
  local explicit_selection=0

  while (($#)); do
    case "$1" in
      --claude)
        if (( ! explicit_selection )); then
          RUN_CLAUDE=0
          RUN_CODEX=0
          RUN_ANTIGRAVITY=0
          explicit_selection=1
        fi
        RUN_CLAUDE=1
        ;;
      --codex)
        if (( ! explicit_selection )); then
          RUN_CLAUDE=0
          RUN_CODEX=0
          RUN_ANTIGRAVITY=0
          explicit_selection=1
        fi
        RUN_CODEX=1
        ;;
      --antigravity)
        if (( ! explicit_selection )); then
          RUN_CLAUDE=0
          RUN_CODEX=0
          RUN_ANTIGRAVITY=0
          explicit_selection=1
        fi
        RUN_ANTIGRAVITY=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac

    shift
  done
}

guard_against_sudo() {
  if [[ -n "${SUDO_USER:-}" ]]; then
    error "Run this script without sudo so CLI packages are installed for your user."
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  local label="${2:-$1}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "Required command not found: $label"
    exit 1
  fi
}

install_claude_code() {
  if command -v claude >/dev/null 2>&1; then
    info "Claude Code is already installed."
    return 0
  fi

  require_cmd "curl"

  info "Installing Claude Code with Anthropic native installer..."
  curl -fsSL https://claude.ai/install.sh | bash
  hash -r || true

  if command -v claude >/dev/null 2>&1; then
    info "Claude Code installed successfully."
    return 0
  fi

  warn "Claude Code was installed, but 'claude' is not visible in PATH in this shell yet."
}

install_codex_cli() {
  if command -v codex >/dev/null 2>&1; then
    info "Codex is already installed."
    return 0
  fi

  require_cmd "curl"

  info "Installing Codex with OpenAI official installer..."
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
  hash -r || true

  if command -v codex >/dev/null 2>&1; then
    info "Codex installed successfully."
    return 0
  fi

  warn "Codex was installed, but 'codex' is not visible in PATH in this shell yet."
}

install_antigravity_cli() {
  if command -v agy >/dev/null 2>&1 || command -v antigravity >/dev/null 2>&1; then
    info "Antigravity CLI is already installed."
    return 0
  fi

  require_cmd "curl"

  info "Installing Antigravity CLI with the official installer..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  hash -r || true

  if command -v agy >/dev/null 2>&1 || command -v antigravity >/dev/null 2>&1; then
    info "Antigravity CLI installed successfully."
    return 0
  fi

  warn "Antigravity CLI was installed, but its binary is not visible in PATH in this shell yet."
}

main() {
  parse_args "$@"
  guard_against_sudo

  echo ""
  echo "=== AI CLI installation ==="

  if (( RUN_CLAUDE )); then
    install_claude_code
  fi

  if (( RUN_CODEX )); then
    install_codex_cli
  fi

  if (( RUN_ANTIGRAVITY )); then
    install_antigravity_cli
  fi

  echo ""
  echo "=== Done ==="
  echo "Processed components:"
  if (( RUN_CLAUDE )); then
    echo "  Claude Code -> claude"
    echo "    Installed via https://claude.ai/install.sh"
  fi
  if (( RUN_CODEX )); then
    echo "  Codex -> codex"
    echo "    Installed via https://chatgpt.com/codex/install.sh"
  fi
  if (( RUN_ANTIGRAVITY )); then
    echo "  Antigravity CLI -> agy / antigravity"
    echo "    Installed via https://antigravity.google/cli/install.sh"
  fi
}

main "$@"
