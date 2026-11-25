#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_helpers/pin_dock_apps.sh
# Pin installed apps to the GNOME dock; existing pins and their order are kept.
# This script is invoked by linux_helpers/setup.sh and is safe to re-run.
# -----------------------------------------------------------------------------

if [[ "${EUID:-$(id -u)}" -eq 0 || -n "${SUDO_USER:-}" ]]; then
  echo "Run this script without sudo; it configures your own user." >&2
  exit 1
fi

SCHEMA='org.gnome.shell'
KEY='favorite-apps'

# Apps to pin, in order; ones that are not installed are skipped.
DOCK_APPS=(
  brave-browser.desktop
  librewolf.desktop
  com.visualstudio.CodeOSS.desktop
  signal-desktop.desktop
  org.keepassxc.KeePassXC.desktop
  org.wireshark.Wireshark.desktop
  virt-manager.desktop
  org.gnome.Ptyxis.desktop
  org.gnome.Nautilus.desktop
)

is_installed() {
  local app="$1"
  local dir dirs=()

  IFS=: read -ra dirs <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/usr/share:/var/lib/snapd/desktop"
  for dir in "${dirs[@]}"; do
    [[ -f "$dir/applications/$app" ]] && return 0
  done
  return 1
}

if ! command -v gsettings >/dev/null 2>&1; then
  printf 'Error: gsettings is required; this helper supports GNOME desktops only.\n' >&2
  exit 1
fi

if ! gsettings list-schemas | grep -Fx "$SCHEMA" >/dev/null; then
  printf 'Error: GNOME Shell settings are unavailable in this session.\n' >&2
  exit 1
fi

if [[ "$(gsettings writable "$SCHEMA" "$KEY")" != 'true' ]]; then
  printf 'Error: dock pins are locked by system policy.\n' >&2
  exit 1
fi

current="$(gsettings get "$SCHEMA" "$KEY")"
# An empty list is printed as "@as []".
current="${current#@as }"
items="${current#[}"
items="${items%]}"
added=()

for app in "${DOCK_APPS[@]}"; do
  [[ "$items" != *"'$app'"* ]] || continue
  is_installed "$app" || continue
  items="${items:+$items, }'$app'"
  added+=("$app")
done

if (( ${#added[@]} == 0 )); then
  printf 'All installed dock apps are already pinned.\n'
  exit 0
fi

gsettings set "$SCHEMA" "$KEY" "[$items]"
# Without a desktop session 'set' exits 0 but saves nothing.
if [[ "$(gsettings get "$SCHEMA" "$KEY")" != "[$items]" ]]; then
  printf 'Error: the setting was not saved; run this from your GNOME desktop session.\n' >&2
  exit 1
fi
printf 'Pinned to dock: %s\n' "${added[*]}"
