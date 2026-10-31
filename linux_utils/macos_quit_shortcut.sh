#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/macos_quit_shortcut.sh
# Configure GNOME's close-window shortcut with a macOS-like Super+Q binding.
# This script is invoked by linux_utils/setup.sh and is safe to re-run.
# -----------------------------------------------------------------------------

SCHEMA='org.gnome.desktop.wm.keybindings'
KEY='close'
TARGET_SHORTCUT="['<Super>q']"
TARGET_ACCELERATOR='<Super>q'

require_gnome_settings() {
  if ! command -v gsettings >/dev/null 2>&1; then
    printf 'Error: gsettings is required; this helper supports GNOME desktops only.\n' >&2
    exit 1
  fi

  if ! gsettings list-schemas | grep -Fxq "$SCHEMA"; then
    printf 'Error: GNOME window-manager settings are unavailable in this session.\n' >&2
    exit 1
  fi

}

require_gnome_settings

clear_super_q_conflicts() {
  local binding schema key value range

  while IFS= read -r binding; do
    [[ "$binding" == *"$TARGET_ACCELERATOR"* ]] || continue

    schema="${binding%% *}"
    binding="${binding#* }"
    key="${binding%% *}"
    value="${binding#* }"

    [[ "$schema" == "$SCHEMA" && "$key" == "$KEY" ]] && continue

    range="$(gsettings range "$schema" "$key" 2>/dev/null || true)"
    if [[ "$range" != 'type as' ]]; then
      continue
    fi

    if [[ "$value" == "$TARGET_SHORTCUT" ]]; then
      gsettings set "$schema" "$key" '[]'
      printf 'Cleared conflicting Super+Q shortcut: %s %s.\n' "$schema" "$key"
    else
      printf 'Warning: Super+Q is also configured by %s %s; leaving its additional shortcuts unchanged.\n' "$schema" "$key" >&2
    fi
  done < <(gsettings list-recursively 2>/dev/null)
}

if [[ "$(gsettings writable "$SCHEMA" "$KEY")" != 'true' ]]; then
  printf 'Error: the GNOME close-window shortcut is locked by system policy.\n' >&2
  exit 1
fi

clear_super_q_conflicts

current_shortcut="$(gsettings get "$SCHEMA" "$KEY")"
if [[ "$current_shortcut" == "$TARGET_SHORTCUT" ]]; then
  printf '%s\n' "GNOME's close-window shortcut is already Super+Q."
  exit 0
fi

gsettings set "$SCHEMA" "$KEY" "$TARGET_SHORTCUT"
printf '%s\n' "Set GNOME's close-window shortcut to Super+Q."
