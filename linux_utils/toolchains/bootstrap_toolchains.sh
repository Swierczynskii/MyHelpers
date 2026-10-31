#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/toolchains/bootstrap_toolchains.sh
# Bootstrap developer toolchains for a single user.
#
# What it does:
# - Installs Node.js from official tarball into ~/.local, enables Corepack, activates pnpm
# - Installs Bun to ~/.local/bun
# - Installs Rust via rustup to ~/.cargo/bin
# - Installs Go from the official archive into ~/.local/go
# - Installs Playwright globally via npm and downloads browser binaries
# - Optionally installs system prerequisites, Podman, and terminal helpers via apt with --system
# - Respects NODE_VERSION (e.g., v22.11.0); otherwise uses latest LTS when possible
# - Adds PATH entries idempotently to common shell profiles
# - Installs uv (Astral) to ~/.local/bin
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
# shellcheck source=technologies/install_tmux.sh
source "$TECH_DIR/install_tmux.sh"
# shellcheck source=technologies/install_fzf.sh
source "$TECH_DIR/install_fzf.sh"
# shellcheck source=technologies/install_top.sh
source "$TECH_DIR/install_top.sh"
# shellcheck source=technologies/install_podman.sh
source "$TECH_DIR/install_podman.sh"
# shellcheck source=technologies/install_node.sh
source "$TECH_DIR/install_node.sh"
# shellcheck source=technologies/install_bun.sh
source "$TECH_DIR/install_bun.sh"
# shellcheck source=technologies/install_playwright.sh
source "$TECH_DIR/install_playwright.sh"
# shellcheck source=technologies/install_uv.sh
source "$TECH_DIR/install_uv.sh"
# shellcheck source=technologies/install_rust.sh
source "$TECH_DIR/install_rust.sh"
# shellcheck source=technologies/install_go.sh
source "$TECH_DIR/install_go.sh"
# shellcheck source=technologies/configure_bash_prompt.sh
source "$TECH_DIR/configure_bash_prompt.sh"
# shellcheck source=technologies/configure_gnome_terminal.sh
source "$TECH_DIR/configure_gnome_terminal.sh"

usage() {
  cat <<'EOF'
Usage: bash linux_utils/toolchains/bootstrap_toolchains.sh [-u|--user] | [-s|--system]

Options:
  -u, --user    Install only user-scoped toolchains and shell config (default)
  -s, --system  Also install apt prerequisites, terminal tools, Podman, and Playwright system deps
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

require_user_prereqs() {
  local missing=()
  local cmd

  for cmd in awk curl grep gzip sed sha256sum tar unzip xz; do
    if ! have "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing required user-mode commands: ${missing[*]}. Install them with your package manager, or rerun with --system to install apt prerequisites."
    exit 1
  fi
}

parse_args "$@"
guard_against_sudo
log "Bootstrapping toolchains..."
if (( SYSTEM_MODE )); then
  section "Installing system prerequisites"
  install_prereqs
  section "Installing terminal and container tools"
  install_tmux
  install_fzf
  install_top
  install_podman
else
  require_user_prereqs
  log "User mode selected; skipping apt prerequisites, terminal tools, Podman, and Playwright system dependencies."
fi
section "Installing Node.js and Corepack"
install_node_corepack
section "Installing Bun"
install_bun
section "Installing Playwright"
install_playwright
section "Installing Rust"
install_rust
section "Installing Go"
install_go
section "Installing uv"
install_uv
section "Configuring shell prompt"
configure_bash_prompt
section "Configuring GNOME Terminal"
configure_gnome_terminal
log "Toolchain bootstrap completed."
