#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/setup.sh
# Orchestrated Linux setup for Debian/Ubuntu (apt).
# - Bootstraps developer toolchains (Node.js + Corepack/pnpm, uv)
# - Runs per-backend tool/app installers inline (apt-only backend allowlist)
# - Ensures lm-sensors and copies monitor.sh to $HOME
# - Copies backend-specific upgrade.sh to $HOME
# - Optionally configures persistent battery thresholds (default 20/80) when supported
# Safe to re-run; individual steps are idempotent.
# -----------------------------------------------------------------------------

COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
fi
if (( COLOR_ENABLED )); then
  export FORCE_COLOR=1
fi

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
  local ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
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

title() {
  print_box "$*" "$TITLE_COLOR"
}

extract_script_title() {
  local script="$1"
  sed -nE 's/^[[:space:]]*title "(.*)"$/\1/p' "$script" | head -n1 || true
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Required command not found: $cmd"
    exit 1
  fi
}

validate_backend() {
  local backend="$1"
  case "$backend" in
    debian_apt) return 0 ;;
    *)
      err "Invalid BACKEND '$backend'. Allowed: debian_apt"
      exit 1
      ;;
  esac
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

run_installer_script() {
  local script="$1"
  local show_title="${2:-0}"
  local script_name
  local script_title

  script_name="$(basename "$script")"
  if [[ ! -x "$script" ]]; then
    err "$script_name is not executable; refusing to change permissions automatically."
    exit 1
  fi

  if (( show_title )); then
    script_title="$(extract_script_title "$script")"
    if [[ -n "$script_title" ]]; then
      title "$script_title"
    fi
  fi

  log "Processing $script_name..."
  if (( show_title )); then
    if SKIP_INSTALLER_TITLE=1 bash "$script"; then
      log "Successfully executed $script_name"
    else
      err "Failed to execute $script_name. Stopping execution."
      exit 1
    fi
    return 0
  fi

  if bash "$script"; then
    log "Successfully executed $script_name"
  else
    err "Failed to execute $script_name. Stopping execution."
    exit 1
  fi
}

run_installers_from_dir() {
  local dir="$1"
  local require_scripts="${2:-0}"
  local show_title="${3:-0}"
  local scripts=()
  local script

  shopt -s nullglob
  scripts=("$dir"/install_*.sh)
  shopt -u nullglob

  if [[ ${#scripts[@]} -eq 0 ]]; then
    if (( require_scripts )); then
      err "No installation scripts found in $dir (pattern: install_*.sh)"
      exit 1
    fi
    log "No scripts found in $dir (pattern: install_*.sh)"
    return 0
  fi

  for script in "${scripts[@]}"; do
    [[ -f "$script" ]] || continue
    run_installer_script "$script" "$show_title"
  done
}

deploy_helper_script() {
  local source_path="$1"
  local destination_path="$2"
  local name="$3"

  if [[ -f "$source_path" ]]; then
    log "Copying $source_path to $destination_path (overwriting)"
    cp -f "$source_path" "$destination_path"
    chmod +x "$destination_path" || true
  else
    log "No $name found at $source_path."
  fi
}

configure_battery_thresholds() {
  local installer="$SCRIPT_DIR/battery_thresholds/persistence/install_service.sh"
  local start_threshold="20"
  local end_threshold="80"
  local keep_default="Y"

  if [[ ! -x "$installer" ]]; then
    log "Battery thresholds installer missing or not executable at $installer (skipping)."
    return 0
  fi

  if [[ -t 0 ]]; then
    read -r -p "Keep default battery thresholds (start=20%, end=80%)? [Y/n]: " keep_default || true
    keep_default="${keep_default:-Y}"

    if [[ "$keep_default" =~ ^[Nn]$ ]]; then
      while true; do
        read -r -p "Enter start threshold (0-100): " start_threshold || true
        if ! is_uint "$start_threshold" || (( start_threshold < 0 || start_threshold > 100 )); then
          echo "Invalid start threshold. Enter an integer from 0 to 100."
          continue
        fi
        break
      done

      while true; do
        read -r -p "Enter end threshold (0-100): " end_threshold || true
        if ! is_uint "$end_threshold" || (( end_threshold < 0 || end_threshold > 100 )); then
          echo "Invalid end threshold. Enter an integer from 0 to 100."
          continue
        fi
        if (( start_threshold >= end_threshold )); then
          echo "End threshold must be greater than start threshold (${start_threshold})."
          continue
        fi
        break
      done
    fi
  else
    log "Non-interactive stdin detected; using default battery thresholds start=20 end=80."
  fi

  log "Configuring persistent battery thresholds: start=${start_threshold}, end=${end_threshold}"
  if sudo bash "$installer" --start "$start_threshold" --end "$end_threshold"; then
    log "Battery thresholds configured successfully."
  else
    warn "Battery threshold configuration failed or is unsupported on this hardware; continuing setup."
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
SETUP_LOG="$LOG_DIR/setup.log"

mkdir -p "$LOG_DIR"
# Overwrite one setup log per run while still streaming to terminal.
exec > >(tee >(sed -E 's/\x1B\[[0-9;]*[mK]//g' > "$SETUP_LOG")) 2>&1
section "Setup started"
log "Writing setup log to: $SETUP_LOG"

# Detect OS pretty name for final message
OS_ID=""
OS_NAME=""
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_NAME="${PRETTY_NAME:-${NAME:-$OS_ID}}"
fi

# Preconditions
require_cmd bash
if ! command -v sudo >/dev/null 2>&1; then
  err "sudo is not available. Installers typically require privilege escalation."
  exit 1
fi

# Backend detection and validation
BACKEND="${BACKEND:-}"
if [[ -z "$BACKEND" ]]; then
  if command -v apt >/dev/null 2>&1; then
    BACKEND="debian_apt"
    log "Detected Debian/Ubuntu (apt) environment."
  else
    err "Unsupported Linux distribution: apt not found."
    exit 1
  fi
else
  log "Using preselected backend: $BACKEND"
fi
validate_backend "$BACKEND"

# 1) Bootstrap developer toolchains (Node.js + Corepack/pnpm, uv)
section "Bootstrapping toolchains"
TOOLCHAIN_BOOTSTRAP="$SCRIPT_DIR/toolchains/bootstrap_toolchains.sh"
if [[ -f "$TOOLCHAIN_BOOTSTRAP" ]]; then
  log "Bootstrapping developer toolchains via $TOOLCHAIN_BOOTSTRAP"
  BACKEND="$BACKEND" bash "$TOOLCHAIN_BOOTSTRAP"
else
  log "Toolchain bootstrap script not found at $TOOLCHAIN_BOOTSTRAP (skipping)."
fi

# 2) Run unified installer orchestrator (inline)
section "Running installers"
APPS_DIR="$SCRIPT_DIR/$BACKEND/apps_installations"
TOOLS_DIR="$SCRIPT_DIR/$BACKEND/tools_installations"

if [[ ! -d "$APPS_DIR" ]]; then
  err "apps_installations directory not found at $APPS_DIR"
  exit 1
fi

log "Starting installation orchestrator for backend: $BACKEND"
log "Apps directory: $APPS_DIR"

# Tools phase
if [[ -d "$TOOLS_DIR" ]]; then
  log "Processing tools from: $TOOLS_DIR"
  run_installers_from_dir "$TOOLS_DIR"
else
  log "No tools_installations directory at $TOOLS_DIR (skipping tools)."
fi

# Apps phase
run_installers_from_dir "$APPS_DIR" 1 1

log "All installation scripts have been executed successfully."

# 2a) Ensure lm-sensors is installed for temperature monitoring (apt-only)
section "Installing monitor prerequisites"
if ! dpkg -s lm-sensors >/dev/null 2>&1; then
  log "Installing lm-sensors (apt-get)..."
  sudo apt-get update || true
  sudo apt-get install -y lm-sensors
else
  log "lm-sensors already installed."
fi

# 3) Copy upgrade helper from backend to $HOME (force overwrite, ensure executable)
section "Deploying helper scripts"
SRC_UPGRADE="$SCRIPT_DIR/$BACKEND/upgrade.sh"
DEST_UPGRADE="$HOME/upgrade.sh"
deploy_helper_script "$SRC_UPGRADE" "$DEST_UPGRADE" 'upgrade.sh'

# 3a) Copy monitor.sh helper to $HOME (force overwrite) and ensure executable
SRC_MONITOR="$SCRIPT_DIR/monitor.sh"
DEST_MONITOR="$HOME/monitor.sh"
deploy_helper_script "$SRC_MONITOR" "$DEST_MONITOR" 'monitor.sh'

# 3b) Copy podman_cleanup.sh helper to $HOME (force overwrite) and ensure executable
SRC_PODMAN_CLEANUP="$SCRIPT_DIR/podman_cleanup.sh"
DEST_PODMAN_CLEANUP="$HOME/podman_cleanup.sh"
deploy_helper_script "$SRC_PODMAN_CLEANUP" "$DEST_PODMAN_CLEANUP" 'podman_cleanup.sh'

# 3c) Configure persistent battery thresholds (best effort; default 20/80)
section "Configuring battery thresholds"
configure_battery_thresholds

section "Setup completed"
log "SUCCESS: Setup completed successfully for ${OS_NAME:-Linux} using backend '$BACKEND'."
