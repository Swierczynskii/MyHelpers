#!/usr/bin/env bash
set -euo pipefail
umask 022

# Apply the VSCodium settings, extensions and UI layout stored in this repo. Safe to re-run.

if [[ "${EUID:-$(id -u)}" -eq 0 || -n "${SUDO_USER:-}" ]]; then
  echo "Run this script without sudo; it configures your own user." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/config"
USER_DIR="$HOME/.config/VSCodium/User"
STAMP="$(date '+%Y%m%d-%H%M%S')"

command -v codium >/dev/null || { echo "codium not found; run install_codium.sh first" >&2; exit 1; }
[[ -d "$SRC" ]] || { echo "No stored configuration: $SRC" >&2; exit 1; }

# Copy a file, keeping a timestamped backup of a different existing one.
apply_file() {
  local src="$1" dest="$2"
  cmp -s "$src" "$dest" && return 0
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]]; then
    cp -p "$dest" "$dest.bak-$STAMP"
  fi
  cp "$src" "$dest"
  echo "Applied $dest"
}

FAILED=0
if [[ -f "$SRC/extensions.txt" ]]; then
  if ! INSTALLED="$(codium --list-extensions 2>/dev/null)"; then
    echo "Warning: could not list installed extensions" >&2
    INSTALLED=""
    FAILED=1
  fi
  while IFS= read -r ext; do
    [[ -n "$ext" ]] || continue
    grep -Fxiq -- "$ext" <<< "$INSTALLED" && continue
    echo "Installing extension $ext"
    if ! codium --install-extension "$ext" </dev/null >/dev/null 2>&1; then
      echo "Warning: could not install $ext" >&2
      FAILED=1
    fi
  done < "$SRC/extensions.txt"
fi

for file in settings.json keybindings.json; do
  if [[ -f "$SRC/$file" ]]; then apply_file "$SRC/$file" "$USER_DIR/$file"; fi
done
for file in "$SRC"/snippets/*; do
  if [[ -f "$file" ]]; then apply_file "$file" "$USER_DIR/snippets/${file##*/}"; fi
done

if [[ -f "$SRC/ui_state.json" ]]; then
  # A running VSCodium would overwrite layout changes when it closes.
  if pgrep -u "$(id -u)" -x codium >/dev/null; then
    echo "VSCodium is running; layout not applied. Close it and re-run this script." >&2
    FAILED=1
  elif ! command -v python3 >/dev/null; then
    echo "Warning: python3 not found; layout not applied" >&2
    FAILED=1
  else
    DB="$USER_DIR/globalStorage/state.vscdb"
    mkdir -p "$(dirname "$DB")"
    if [[ -f "$DB" ]]; then
      # Keep only the latest backup; these may contain tokens.
      rm -f "$DB".bak-*
      install -m 0600 "$DB" "$DB.bak-$STAMP"
    fi
    python3 -I "$SCRIPT_DIR/ui_state.py" import "$DB" "$SRC/ui_state.json"
    echo "Applied UI layout"
  fi
fi

(( FAILED == 0 )) || { echo "VSCodium configured with warnings." >&2; exit 1; }
echo "VSCodium configured."
