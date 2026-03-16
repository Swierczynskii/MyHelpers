#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_pgadmin.sh
# Install pgAdmin 4 via the official pgAdmin APT repository.
# Supports web, desktop, or both variants and detects existing installs first.
# Usage: ./install_pgadmin.sh
# Non-interactive: export DEBIAN_FRONTEND=noninteractive
# -----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

COLOR_ENABLED=0
if [[ "${FORCE_COLOR:-0}" == "1" || -t 1 ]]; then
  COLOR_ENABLED=1
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

title() {
  print_box "$*" "$TITLE_COLOR"
}

if [[ "${SKIP_INSTALLER_TITLE:-0}" != "1" ]]; then
  title "Installing pgAdmin"
fi

if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

is_interactive() {
  [[ -t 0 && -t 1 ]]
}

detect_pgadmin_web() {
  if pkg_installed pgadmin4 || pkg_installed pgadmin4-web; then
    echo "package"
  elif [[ -x /usr/pgadmin4/bin/setup-web.sh ]] || [[ -f /usr/pgadmin4/web/pgAdmin4.py ]]; then
    echo "filesystem"
  else
    echo ""
  fi
}

detect_pgadmin_desktop() {
  if pkg_installed pgadmin4 || pkg_installed pgadmin4-desktop; then
    echo "package"
  elif command -v pgadmin4 >/dev/null 2>&1 || [[ -f /usr/share/applications/pgadmin4.desktop ]]; then
    echo "filesystem"
  else
    echo ""
  fi
}

confirm_install_other() {
  local installed_mode="$1"
  local missing_mode="$2"
  local response

  if ! is_interactive; then
    log "Detected existing pgAdmin ${installed_mode} install, but stdin is non-interactive."
    log "Skipping installation of pgAdmin ${missing_mode}."
    return 1
  fi

  while true; do
    read -r -p "pgAdmin ${installed_mode} is already installed. Install pgAdmin ${missing_mode} as well? [y/N]: " response || true
    case "${response,,}" in
      y|yes) return 0 ;;
      n|no|'') return 1 ;;
      *) printf 'Please answer y or n.\n' ;;
    esac
  done
}

MODE=""
web_detected="$(detect_pgadmin_web)"
desktop_detected="$(detect_pgadmin_desktop)"

if [[ -n "$web_detected" && -n "$desktop_detected" ]]; then
  log "pgAdmin web and desktop are already present on this system. Skipping."
  exit 0
elif [[ -n "$web_detected" ]]; then
  log "Detected existing pgAdmin web install (${web_detected})."
  if confirm_install_other "web" "desktop"; then
    MODE="desktop"
  else
    log "Skipping pgAdmin desktop installation."
    exit 0
  fi
elif [[ -n "$desktop_detected" ]]; then
  log "Detected existing pgAdmin desktop install (${desktop_detected})."
  if confirm_install_other "desktop" "web"; then
    MODE="web"
  else
    log "Skipping pgAdmin web installation."
    exit 0
  fi
fi

log "Ensuring prerequisites..."
need_curl=0
need_gpg=0
need_lsb=0
need_ca=0
command -v curl >/dev/null 2>&1 || need_curl=1
command -v gpg >/dev/null 2>&1 || need_gpg=1
command -v lsb_release >/dev/null 2>&1 || need_lsb=1
[[ -f /etc/ssl/certs/ca-certificates.crt ]] || need_ca=1
if (( need_curl || need_gpg || need_lsb || need_ca )); then
  sudo apt-get update || true
  sudo apt-get install -y curl gnupg lsb-release ca-certificates || true
fi

PGADMIN_KEYRING='/usr/share/keyrings/packages-pgadmin-org.gpg'
PGADMIN_LIST='/etc/apt/sources.list.d/pgadmin4.list'
CODENAME="$(lsb_release -cs)"

log "Ensuring pgAdmin GPG key..."
if [[ -f "$PGADMIN_KEYRING" ]]; then
  log "Using existing keyring: $PGADMIN_KEYRING"
else
  log "Downloading pgAdmin key and writing to $PGADMIN_KEYRING"
  curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o "$PGADMIN_KEYRING"
  sudo chmod 0644 "$PGADMIN_KEYRING"
fi

log "Cleaning duplicate pgAdmin APT sources..."
sudo sed -i -E '/pgadmin4\/apt\//d' /etc/apt/sources.list || true
sudo bash -lc 'for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do [ -e "$f" ] || continue; if grep -qs "pgadmin4/apt/" "$f"; then rm -f "$f"; fi; done'

log "Adding pgAdmin APT repository..."
printf 'deb [signed-by=%s] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/%s pgadmin4 main
' "$PGADMIN_KEYRING" "$CODENAME" | sudo tee "$PGADMIN_LIST" >/dev/null
sudo chmod 0644 "$PGADMIN_LIST"

log "Updating package lists..."
sudo apt-get update

if [[ -z "$MODE" ]]; then
  MODE='both'
  if is_interactive; then
    log 'Select pgAdmin installation mode:'
    log '  1) Web (online)      -> package: pgadmin4-web'
    log '  2) Desktop (on-prem) -> package: pgadmin4-desktop'
    log '  3) Both              -> package: pgadmin4'
    read -r -p 'Enter choice [1-3, default 3]: ' CHOICE || true
    case "${CHOICE:-3}" in
      1) MODE='web' ;;
      2) MODE='desktop' ;;
      3|*) MODE='both' ;;
    esac
  else
    log "Non-interactive stdin detected; defaulting to 'Both'."
  fi
fi

install_pkg() {
  local pkg="$1"
  if pkg_installed "$pkg"; then
    log "$pkg already installed. Skipping."
  else
    log "Installing $pkg ..."
    sudo apt-get install -y "$pkg"
  fi
}

NEED_WEB_SETUP=0
case "$MODE" in
  web)
    install_pkg pgadmin4-web
    NEED_WEB_SETUP=1
    ;;
  desktop)
    install_pkg pgadmin4-desktop
    ;;
  both)
    install_pkg pgadmin4
    NEED_WEB_SETUP=1
    ;;
  *)
    err "Unknown mode: $MODE"
    exit 2
    ;;
esac

if (( NEED_WEB_SETUP )); then
  if [[ -x /usr/pgadmin4/bin/setup-web.sh ]]; then
    if is_interactive; then
      log 'Running pgAdmin web setup...'
      sudo /usr/pgadmin4/bin/setup-web.sh || true
    else
      warn 'Web setup skipped (non-interactive). To configure later, run:'
      log '    sudo /usr/pgadmin4/bin/setup-web.sh'
    fi
  else
    warn 'setup-web.sh not found at /usr/pgadmin4/bin/setup-web.sh. Skipping web configuration.'
  fi
fi

log 'pgAdmin installation complete.'
case "$MODE" in
  web) log 'Installed: pgadmin4-web' ;;
  desktop) log 'Installed: pgadmin4-desktop' ;;
  both) log 'Installed: pgadmin4 (both web and desktop)' ;;
esac
if (( NEED_WEB_SETUP )); then
  log 'If you skipped web setup, run: sudo /usr/pgadmin4/bin/setup-web.sh'
fi
log "Launch desktop: pgadmin4 (from your app menu or 'pgadmin4' if available)"
log 'Web access (after setup): http://127.0.0.1/pgadmin4 or configured host'
