#!/usr/bin/env bash
set -euo pipefail
umask 022
# Set default GNOME Terminal and Ptyxis (default terminal since Ubuntu 25.10) profile transparency.
# Usable standalone (bash technologies/configure_gnome_terminal.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

configure_ptyxis() {
  local transparency="$1"
  local profile_id opacity schema

  if ! have gsettings || ! gsettings list-schemas | grep -Fx 'org.gnome.Ptyxis' >/dev/null; then
    log 'Ptyxis settings are unavailable; skipping transparency configuration.'
    return
  fi

  profile_id="$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null || true)"
  profile_id="${profile_id//\'/}"
  if [[ -z "$profile_id" ]]; then
    warn 'Ptyxis has no default profile yet; open it once and rerun setup.'
    return
  fi

  printf -v opacity '%d.%02d' "$(( (100 - transparency) / 100 ))" "$(( (100 - transparency) % 100 ))"
  schema="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${profile_id}/"
  # Read back: without a desktop session 'set' exits 0 but saves nothing (doubles may print as 0.92000000000000004).
  if ! gsettings set "$schema" opacity "$opacity" ||
     ! gsettings get "$schema" opacity | LC_ALL=C awk -v want="$opacity" '{ d = $1 - want; exit !(d < 0.001 && d > -0.001) }'; then
    warn 'Unable to update Ptyxis transparency. Run setup from your GNOME desktop session and try again.'
    return
  fi
  log "Set default Ptyxis profile transparency to ${transparency}%."
}

configure_gnome_terminal() {
  local transparency="${GNOME_TERMINAL_TRANSPARENCY:-8}"
  if [[ ! "$transparency" =~ ^([0-9]|[1-9][0-9]|100)$ ]]; then
    warn "GNOME_TERMINAL_TRANSPARENCY must be an integer from 0 to 100; skipping GNOME Terminal configuration."
    return
  fi

  configure_ptyxis "$transparency"

  if ! have gsettings || ! gsettings list-schemas | grep -Fx 'org.gnome.Terminal.ProfilesList' >/dev/null; then
    log 'GNOME Terminal settings are unavailable; skipping transparency configuration.'
    return
  fi

  local profile_id
  profile_id="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null || true)"
  profile_id="${profile_id//\'/}"
  if [[ -z "$profile_id" ]]; then
    warn 'GNOME Terminal has no default profile; skipping transparency configuration.'
    return
  fi

  local profile_schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile_id}/"
  if [[ "$(gsettings writable "$profile_schema" use-transparent-background 2>/dev/null || true)" != 'true' ||
        "$(gsettings writable "$profile_schema" background-transparency-percent 2>/dev/null || true)" != 'true' ]]; then
    warn 'The default GNOME Terminal profile is locked; skipping transparency configuration.'
    return
  fi

  if ! gsettings set "$profile_schema" use-transparent-background true ||
     ! gsettings set "$profile_schema" background-transparency-percent "$transparency" ||
     [[ "$(gsettings get "$profile_schema" use-transparent-background)" != 'true' ||
        "$(gsettings get "$profile_schema" background-transparency-percent)" != "$transparency" ]]; then
    warn 'Unable to update GNOME Terminal transparency. Run setup from your GNOME desktop session and try again.'
    return
  fi

  log "Set default GNOME Terminal profile transparency to ${transparency}%."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  configure_gnome_terminal
fi
