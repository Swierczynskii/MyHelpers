#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/toolchains/bootstrap_toolchains.sh
# Bootstrap developer toolchains for a single user.
#
# What it does:
# - With --system: installs apt prerequisites, mise (signed APT repo), Podman, and terminal helpers
# - Installs global toolchains with mise: Node.js LTS, pnpm, Go, Rust (stable), Bun, uv, sqlite3def
#   (Python versions are managed by uv; per-project versions go in each repo's mise.toml)
# - Installs Playwright globally via npm and downloads browser binaries
# - Adds mise activation/shims and PATH entries idempotently to shell profiles
# - Sets the default GNOME Terminal profile to 8% transparency when available
#
# Behavior:
# - Idempotent and safe to re-run; will skip work when tools already available
# - Does not modify permissions outside intended install locations
#
# Each tool is implemented in technologies/*.sh (shared helpers in technologies/common.sh).
#
# Notes:
# - Internet connection required
# - New shells may be required for PATH changes to take effect
# -----------------------------------------------------------------------------


TECH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/technologies"
# shellcheck source=technologies/common.sh
source "$TECH_DIR/common.sh"
# Each technology lives in technologies/<name>.sh; sourced here so PATH changes carry over.
# shellcheck source=technologies/install_prereqs.sh
source "$TECH_DIR/install_prereqs.sh"
# shellcheck source=technologies/install_mise.sh
source "$TECH_DIR/install_mise.sh"
# shellcheck source=technologies/install_tmux.sh
source "$TECH_DIR/install_tmux.sh"
# shellcheck source=technologies/install_fzf.sh
source "$TECH_DIR/install_fzf.sh"
# shellcheck source=technologies/install_top.sh
source "$TECH_DIR/install_top.sh"
# shellcheck source=technologies/install_podman.sh
source "$TECH_DIR/install_podman.sh"
# shellcheck source=technologies/configure_mise_tools.sh
source "$TECH_DIR/configure_mise_tools.sh"
# shellcheck source=technologies/install_playwright.sh
source "$TECH_DIR/install_playwright.sh"
# shellcheck source=technologies/configure_bash_prompt.sh
source "$TECH_DIR/configure_bash_prompt.sh"
# shellcheck source=technologies/configure_gnome_terminal.sh
source "$TECH_DIR/configure_gnome_terminal.sh"

usage() {
  cat <<'EOF'
Usage: bash linux_utils/toolchains/bootstrap_toolchains.sh [-u|--user] | [-s|--system]

Options:
  -u, --user    Install only mise-managed toolchains and shell config; requires mise (default)
  -s, --system  Also install apt prerequisites, mise, terminal tools, Podman, and Playwright system deps
  -h, --help  Show this help message

Run this script as your normal user. It calls sudo only for explicit --system steps.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      -u|--user|--user-only)
        SYSTEM_MODE=0
        ;;
      -s|--system)
        SYSTEM_MODE=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  case "${SYSTEM_MODE}" in
    1|true|TRUE|yes|YES) SYSTEM_MODE=1 ;;
    0|false|FALSE|no|NO|'') SYSTEM_MODE=0 ;;
    *)
      err "Invalid MYHELPERS_SYSTEM value: ${SYSTEM_MODE}. Use 0 or 1."
      exit 1
      ;;
  esac
}

parse_args "$@"
guard_against_sudo
log "Bootstrapping toolchains..."
if (( SYSTEM_MODE )); then
  section "Installing system prerequisites"
  install_prereqs
  section "Installing mise"
  install_mise
  section "Installing terminal and container tools"
  install_tmux
  install_fzf
  install_top
  install_podman
else
  log "User mode selected; skipping apt prerequisites, mise installation, terminal tools, Podman, and Playwright system dependencies."
fi
section "Installing global toolchains with mise"
configure_mise_tools
section "Installing Playwright"
install_playwright
section "Configuring shell prompt"
configure_bash_prompt
section "Configuring GNOME Terminal"
configure_gnome_terminal
log "Toolchain bootstrap completed."
