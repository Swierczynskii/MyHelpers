#!/usr/bin/env bash
set -euo pipefail
umask 022
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

if [[ "${SKIP_INSTALLER_TITLE:-0}" != "1" ]]; then
  title "Installing KVM + Virtual Machine Manager"
fi

if ! command -v apt >/dev/null 2>&1; then
  err "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

if ! grep -qE '(vmx|svm)' /proc/cpuinfo; then
  err "CPU virtualization (VT-x/AMD-V) not available. Enable it in BIOS/UEFI (or the hypervisor) and re-run."
  exit 1
fi

PACKAGES=(qemu-system-x86 libvirt-daemon-system libvirt-clients virt-manager ovmf)
MISSING=()
for pkg in "${PACKAGES[@]}"; do
  dpkg -s "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
done

if (( ${#MISSING[@]} )); then
  log "Installing: ${MISSING[*]}"
  sudo apt-get update
  sudo apt-get install -y "${MISSING[@]}"
else
  log "KVM/libvirt/virt-manager packages already installed."
fi

log "Enabling libvirt daemon..."
sudo systemctl enable --now libvirtd || log "Could not enable libvirtd (socket-activated setups can ignore this)."

# Add the invoking user (not root) to the libvirt/kvm groups
TARGET_USER="${SUDO_USER:-$USER}"
if [[ "$TARGET_USER" != "root" ]]; then
  for grp in libvirt kvm; do
    if getent group "$grp" >/dev/null && ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx "$grp"; then
      log "Adding $TARGET_USER to group $grp..."
      sudo usermod -aG "$grp" "$TARGET_USER"
      NEED_RELOGIN=1
    fi
  done
fi

log "KVM + virt-manager installation complete."
log "Launch: virt-manager"
if [[ "${NEED_RELOGIN:-0}" == "1" ]]; then
  log "Log out and back in (or run 'newgrp libvirt') for group membership to apply."
fi
