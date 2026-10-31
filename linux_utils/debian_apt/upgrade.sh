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
#   --rust         Rust toolchain (rustup update)
#   --go           Detected Go installation (MyHelpers, official /usr/local/go, or APT)
#   --uv           uv (uv self update)
#   --bun          Bun runtime (bun upgrade)
#   -h, --help     Show usage and exit
#
# Tool upgrades are user-scoped (no sudo) and skip gracefully if the tool
# isn't installed.
# -----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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

get_latest_go_version() {
  curl -fsSL 'https://go.dev/VERSION?m=text' | awk 'NR == 1 { print; exit }'
}

download_go_release() {
  local version="$1"
  local tmp="$2"
  local arch

  case "$(uname -m)" in
    x86_64) arch='amd64' ;;
    aarch64|arm64) arch='arm64' ;;
    *)
      err "Unsupported architecture $(uname -m) for Go archive."
      return 1
      ;;
  esac

  local tarball="${version}.linux-${arch}.tar.gz"
  if ! curl -fsSL 'https://go.dev/dl/?mode=json' -o "$tmp/releases.json"; then
    err 'Unable to download Go release metadata.'
    return 1
  fi

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
    return 1
  fi

  if ! curl -fsSL "https://go.dev/dl/${tarball}" -o "$tmp/$tarball"; then
    err "Unable to download ${tarball}."
    return 1
  fi
  if ! printf '%s  %s\n' "$checksum" "$tmp/$tarball" | sha256sum -c - >/dev/null; then
    err "Checksum verification failed for ${tarball}."
    return 1
  fi
  if ! tar -C "$tmp" -xzf "$tmp/$tarball"; then
    err "Unable to extract ${tarball}."
    return 1
  fi
}

update_myhelpers_go() {
  local go_root="$HOME/.local/go"
  local current_version
  local latest_version
  current_version="$("$go_root/bin/go" version | awk '{print $3}')"
  if ! latest_version="$(get_latest_go_version)" || [[ -z "$latest_version" ]]; then
    err 'Unable to determine the latest stable Go version.'
    return 1
  fi
  if [[ "$current_version" == "$latest_version" ]]; then
    log "Go already up to date: ${current_version}"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  log "Updating MyHelpers Go from ${current_version} to ${latest_version}..."
  if ! download_go_release "$latest_version" "$tmp"; then
    rm -rf -- "$tmp"
    return 1
  fi

  local target="$HOME/.local/go-${latest_version#go}"
  local previous_target
  previous_target="$(readlink -f "$go_root")"
  rm -rf "$target"
  mv "$tmp/go" "$target"
  ln -sfn "$target" "$go_root"

  if [[ "$previous_target" == "$HOME/.local/go-"* && "$previous_target" != "$target" ]]; then
    rm -rf "$previous_target"
  fi

  log "Go updated: $("$go_root/bin/go" version)"
  rm -rf -- "$tmp"
}

update_official_system_go() {
  local go_root='/usr/local/go'
  local current_version
  local latest_version
  current_version="$("$go_root/bin/go" version | awk '{print $3}')"
  if ! latest_version="$(get_latest_go_version)" || [[ -z "$latest_version" ]]; then
    err 'Unable to determine the latest stable Go version.'
    return 1
  fi
  if [[ "$current_version" == "$latest_version" ]]; then
    log "Go already up to date: ${current_version}"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  log "Updating official system Go from ${current_version} to ${latest_version}..."
  if ! download_go_release "$latest_version" "$tmp"; then
    rm -rf -- "$tmp"
    return 1
  fi

  local backup="${go_root}.previous-${current_version}"
  if [[ -e "$backup" || -L "$backup" ]]; then
    err "Refusing to replace ${go_root}: rollback backup already exists at ${backup}."
    rm -rf -- "$tmp"
    return 1
  fi

  if ! sudo mv "$go_root" "$backup"; then
    err "Unable to create rollback backup at ${backup}."
    rm -rf -- "$tmp"
    return 1
  fi
  if ! sudo mv "$tmp/go" "$go_root"; then
    sudo mv "$backup" "$go_root" || err "Failed to restore ${go_root} from ${backup}."
    err 'Unable to install the updated Go release.'
    rm -rf -- "$tmp"
    return 1
  fi

  log "Go updated: $("$go_root/bin/go" version)"
  log "Rollback backup retained at ${backup}. Remove it manually after verifying the new Go installation."
  rm -rf -- "$tmp"
}

update_go() {
  local inspector="$SCRIPT_DIR/../toolchains/inspect_go_installation.sh"
  if [[ ! -f "$inspector" ]]; then
    inspector="$HOME/inspect_go_installation.sh"
  fi
  if [[ ! -f "$inspector" ]]; then
    err "Go installation inspector not found: ${inspector}"
    return 1
  fi

  local installation_type
  installation_type="$(bash "$inspector" --format=machine)"
  case "$installation_type" in
    myhelpers-user) update_myhelpers_go ;;
    official-system) update_official_system_go ;;
    apt) log 'Go is managed by APT; it was updated during the apt upgrade phase.' ;;
    snap) log 'Go is managed by Snap; use snap refresh or its normal refresh schedule.' ;;
    not-installed) log 'Go is not installed; skipping.' ;;
    unknown) log 'Go uses an unrecognized installation method; skipping. Run inspect_go_installation.sh for details.' ;;
    *)
      err "Unexpected Go installation type: ${installation_type}"
      return 1
      ;;
  esac
}

# Dispatch a single tool name to its concrete update command.
run_tool_update() {
  local tool="$1"

  case "$tool" in
    claude) update_tool claude 'Claude Code' claude update ;;
    rust) update_tool rustup 'Rust (rustup)' rustup update ;;
    go) update_go ;;
    uv) update_tool uv 'uv' uv self update ;;
    bun) update_tool bun 'Bun' bun upgrade ;;
    *)
      err "Unknown tool: $tool"
      return 1
      ;;
  esac
}

# Canonical order in which tools run; also the set of valid --<tool> flags.
ALL_TOOLS=(claude rust go uv bun)
AI_TOOLS=(claude)

usage() {
  cat <<'EOF'
Usage: upgrade.sh [FLAGS]

Default (no flags): apt-get update, upgrade -y, autoremove -y.

Flags add tool upgrades AFTER the apt steps:
  --all          apt steps + every tool below
  --ai           AI CLIs: claude
  --claude       Claude Code CLI
  --rust         Rust toolchain (rustup update)
  --go           Detected Go installation (MyHelpers, official /usr/local/go, or APT)
  --uv           uv (uv self update)
  --bun          Bun runtime (bun upgrade)
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
