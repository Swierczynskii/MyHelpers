# shellcheck shell=bash
# shellcheck disable=SC2034
# Shared helpers for toolchain scripts. Source this file; do not run it.
[[ -n "${MYHELPERS_COMMON_LOADED:-}" ]] && return 0
MYHELPERS_COMMON_LOADED=1

COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
fi

SYSTEM_MODE="${MYHELPERS_SYSTEM:-0}"

TIMESTAMP_COLOR='\033[1;36m'
TITLE_COLOR='\033[0;34m'
ERROR_COLOR='\033[1;31m'
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

warn() {
  print_box "WARNING\n$*" "$TITLE_COLOR"
}

err() {
  print_box "ERROR\n$*" "$ERROR_COLOR" >&2
}

section() {
  local title="$1"
  print_box "$title" "$TITLE_COLOR"
}

have() { command -v "$1" >/dev/null 2>&1; }

guard_against_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 || -n "${SUDO_USER:-}" ]]; then
    err "Run this script without sudo. It installs user toolchains into your home directory and calls sudo only for explicit --system steps."
    exit 1
  fi
}

apt_pkg_available() {
  local pkg="$1"
  local cand
  cand="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2}')"
  [[ -n "$cand" && "$cand" != "(none)" ]]
}

# Utilities
append_unique_line() {
  # $1: file, $2: line to append if not present (exact match)
  local file="$1"
  local line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf "\n%s\n" "$line" >> "$file"
  fi
}

ensure_path_entry() {
  # $1: export line (e.g., export PATH="$HOME/.local/bin:$PATH")
  # Adds to common profiles idempotently
  local line="$1"
  local shell_profiles=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile")
  for f in "${shell_profiles[@]}"; do
    # Never create ~/.bash_profile: once it exists, bash login shells stop reading ~/.profile.
    if [[ "$f" == "$HOME/.bash_profile" && ! -f "$f" ]]; then
      continue
    fi
    append_unique_line "$f" "$line"
  done
}

require_sudo() {
  if ! have sudo; then
    err "sudo is required for system-wide package installation."
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  if ! have "$cmd"; then
    err "Required command not found: $cmd"
    exit 1
  fi
}
