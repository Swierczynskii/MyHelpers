#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/upgrade.sh
# Non-interactive APT upgrade helper for Debian/Ubuntu.
#
# Default (no flags): apt-get update, upgrade -y, autoremove -y.
#
# Optional tool upgrades run AFTER the apt steps when requested via flags:
#   --all          apt steps + every tool below
#   --ai           AI CLIs: claude
#   --claude       Claude Code CLI
#   --mise         mise-managed tools (mise upgrade: Node.js, pnpm, Go, Bun, uv, sqlite3def, ...)
#   --rust         Rust stable toolchain (rustup update)
#   -h, --help     Show usage and exit
#
# Tool upgrades are user-scoped (no sudo) and skip gracefully if the tool
# isn't installed. mise itself is updated by the apt steps.
# -----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
fi

TIMESTAMP_COLOR='\033[1;36m'
ERROR_COLOR='\033[1;31m'
TITLE_COLOR='\033[0;34m'
NC='\033[0m'

strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

repeat_char() {
  local char="$1"
  local count="$2"
  local output=''
  local index

  for ((index = 0; index < count; index++)); do
    output+="$char"
  done

  printf '%s' "$output"
}

print_box() {
  local full_text="$1"
  local color="${2:-}"
  local rendered_text
  local line
  local clean_line
  local max_len=0
  local line_len
  local horizontal_line

  rendered_text="$(printf '%b' "$full_text")"

  while IFS= read -r line; do
    clean_line="$(printf '%s\n' "$line" | strip_ansi)"
    line_len=${#clean_line}
    if (( line_len > max_len )); then
      max_len=$line_len
    fi
  done <<< "$rendered_text"

  horizontal_line="$(repeat_char '═' "$((max_len + 4))")"

  if (( COLOR_ENABLED )) && [[ -n "$color" ]]; then
    printf '%b╔%s╗%b\n' "$color" "$horizontal_line" "$NC"
    while IFS= read -r line; do
      printf '%b║  %b%-*s%b  ║%b\n' "$color" "$NC" "$max_len" "$line" "$color" "$NC"
    done <<< "$rendered_text"
    printf '%b╚%s╝%b\n' "$color" "$horizontal_line" "$NC"
  else
    printf '╔%s╗\n' "$horizontal_line"
    while IFS= read -r line; do
      printf '║  %-*s  ║\n' "$max_len" "$line"
    done <<< "$rendered_text"
    printf '╚%s╝\n' "$horizontal_line"
  fi
}

timestamp() {
  local ts
  ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
  if (( COLOR_ENABLED )); then
    printf '%b%s%b' "$TIMESTAMP_COLOR" "$ts" "$NC"
  else
    printf '%s' "$ts"
  fi
}

log() {
  printf '%s %s\n' "$(timestamp)" "$*"
}

err() {
  print_box "ERROR\n$*" "$ERROR_COLOR" >&2
}

title() {
  print_box "$*" "$TITLE_COLOR"
}

guard_against_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 || -n "${SUDO_USER:-}" ]]; then
    err "Run this script without sudo. It calls sudo only for the apt steps, and tool upgrades must run as your normal user (running them as root corrupts ownership of ~/.cargo and ~/.local)."
    exit 1
  fi
}

# Run an update command for a tool, skipping gracefully when it isn't installed.
# Usage: update_tool <detect-cmd> <label> <cmd> [args...]
update_tool() {
  local cmd="$1"
  local label="$2"
  shift 2

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "$label not installed; skipping."
    return 0
  fi

  log "Updating $label..."
  if ! "$@"; then
    err "$label update failed."
    return 1
  fi
}

# Dispatch a single tool name to its concrete update command.
run_tool_update() {
  local tool="$1"

  case "$tool" in
    claude) update_tool claude 'Claude Code' claude update ;;
    mise) update_tool mise 'mise-managed tools' mise upgrade ;;
    rust) update_tool rustup 'Rust (rustup)' rustup update ;;
    *)
      err "Unknown tool: $tool"
      return 1
      ;;
  esac
}

# Canonical order in which tools run; also the set of valid --<tool> flags.
ALL_TOOLS=(claude mise rust)
AI_TOOLS=(claude)

usage() {
  cat <<'EOF'
Usage: upgrade.sh [FLAGS]

Default (no flags): apt-get update, upgrade -y, autoremove -y.

Flags add tool upgrades AFTER the apt steps:
  --all          apt steps + every tool below
  --ai           AI CLIs: claude
  --claude       Claude Code CLI
  --mise         mise-managed tools (mise upgrade: Node.js, pnpm, Go, Bun, uv, sqlite3def, ...)
  --rust         Rust stable toolchain (rustup update)
  -h, --help     Show this help and exit
EOF
}

# Parse flags into a dedup set of requested tools (keys of `requested`).
declare -A requested=()

add_tool() { requested["$1"]=1; }

while (( $# )); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --all)
      for t in "${ALL_TOOLS[@]}"; do add_tool "$t"; done
      ;;
    --ai)
      for t in "${AI_TOOLS[@]}"; do add_tool "$t"; done
      ;;
    --*)
      tool="${1#--}"
      matched=0
      for t in "${ALL_TOOLS[@]}"; do
        if [[ "$t" == "$tool" ]]; then
          add_tool "$t"
          matched=1
          break
        fi
      done
      if (( ! matched )); then
        err "Unknown flag: $1"
        usage >&2
        exit 1
      fi
      ;;
    *)
      err "Unexpected argument: $1"
      usage >&2
      exit 1
      ;;
  esac
  shift
done

guard_against_sudo

title 'Starting system upgrade'

log 'Running apt-get update...'
if ! sudo apt-get update; then
  err 'apt-get update failed.'
  exit 1
fi

log 'Running apt-get upgrade -y...'
if ! sudo apt-get upgrade -y; then
  err 'apt-get upgrade failed.'
  exit 1
fi

log 'Running apt-get autoremove -y...'
if ! sudo apt-get autoremove -y; then
  err 'apt-get autoremove failed.'
  exit 1
fi

# Run requested tool upgrades in canonical order, after the apt steps.
if (( ${#requested[@]} )); then
  log 'Updating requested tools...'
  tool_update_failed=0
  for tool in "${ALL_TOOLS[@]}"; do
    if [[ -n "${requested[$tool]:-}" ]]; then
      run_tool_update "$tool" || tool_update_failed=1
    fi
  done
  if (( tool_update_failed )); then
    err 'One or more tool updates failed.'
    exit 1
  fi
fi

title $'System upgrade completed successfully.\nYour system is now up to date.'
