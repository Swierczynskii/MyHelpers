#!/usr/bin/env bash
set -euo pipefail
umask 022

# Export VSCodium settings, extension list and UI layout (Default profile) into this repo.
# Files are replaced only when no likely sensitive data is found.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DIR="$HOME/.config/VSCodium/User"
DEST="$SCRIPT_DIR/config"

for cmd in codium python3; do
  command -v "$cmd" >/dev/null || { echo "$cmd not found" >&2; exit 1; }
done
[[ -f "$USER_DIR/settings.json" ]] || { echo "No VSCodium settings found in $USER_DIR" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for file in settings.json keybindings.json; do
  if [[ -f "$USER_DIR/$file" ]]; then cp "$USER_DIR/$file" "$TMP/$file"; fi
done
if [[ -n "$(ls -A "$USER_DIR/snippets" 2>/dev/null)" ]]; then
  # -L: scan and copy file contents, not links.
  cp -rL "$USER_DIR/snippets" "$TMP/snippets"
fi
codium --list-extensions 2>/dev/null | sort > "$TMP/extensions.txt"
if [[ -f "$USER_DIR/globalStorage/state.vscdb" ]]; then
  python3 -I "$SCRIPT_DIR/ui_state.py" export "$USER_DIR/globalStorage/state.vscdb" "$TMP/ui_state.json"
fi

# Best-effort check for credentials, email addresses and home paths; prints locations, not values.
SENSITIVE='(api[-_]?key|access[-_]?key|private[-_]?key|password|passwd|secret|credential|token|[_-]pat|authorization|bearer|cookie)s?"[[:space:]]*:[[:space:]]*("[^"]|$)|(api[-_]?key|access[-_]?key|private[-_]?key|password|passwd|secret|token|[_-]pat)=.?[^[:space:]"$]|gh[pousr]_[A-Za-z0-9]{20}|github_pat_|sk-[A-Za-z0-9_-]{16}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|://[^/ ":]+:[^/ "@]+@|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}|/home/[a-z]'
GREP_STATUS=0
HITS="$(grep -rniE -- "$SENSITIVE" "$TMP")" || GREP_STATUS=$?
if (( GREP_STATUS > 1 )); then
  echo "Sensitive data check failed; nothing exported." >&2
  exit 1
fi
if [[ -n "$HITS" ]]; then
  HITS="$(cut -d: -f1,2 <<< "$HITS")"
  echo "Possible sensitive data found; nothing exported. Review:" >&2
  printf '%s\n' "${HITS//$TMP/$USER_DIR}" >&2
  exit 1
fi

mkdir -p "$DEST"
rm -rf "$DEST/snippets"
rm -f "$DEST"/{settings.json,keybindings.json,extensions.txt,ui_state.json}
cp -r "$TMP"/. "$DEST"/
chmod 0755 "$DEST"
echo "Exported VSCodium configuration -> $DEST"
echo "Review 'git diff' before committing."
