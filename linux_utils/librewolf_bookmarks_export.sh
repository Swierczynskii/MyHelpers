#!/usr/bin/env bash
set -euo pipefail
umask 022

# Export LibreWolf bookmarks (Netscape HTML, importable) to ~/Sync.
# Usage: librewolf_bookmarks_export.sh [profile_dir]   (default: first profile with places.sqlite)

OUT_DIR="$HOME/Sync"
OUT="$OUT_DIR/librewolf_bookmarks.html"

command -v sqlite3 >/dev/null || { echo "sqlite3 not installed (sudo apt-get install sqlite3)" >&2; exit 1; }

if [[ -n "${1:-}" ]]; then
  DB="$1/places.sqlite"
else
  DB=""
  for f in "$HOME"/.librewolf/*/places.sqlite \
           "$HOME"/.var/app/io.gitlab.librewolf-community/.librewolf/*/places.sqlite; do
    [[ -f "$f" ]] && { DB="$f"; break; }
  done
fi
[[ -f "$DB" ]] || { echo "places.sqlite not found; pass profile dir as argument" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Copy (with WAL) so a running browser's lock doesn't block us.
cp "$DB" "$TMP/places.sqlite"
[[ -f "$DB-wal" ]] && cp "$DB-wal" "$TMP/places.sqlite-wal"

mkdir -p "$OUT_DIR"
# Netscape bookmark HTML: import via LibreWolf > Bookmarks > Manage > Import and Backup > Import from HTML.
# ponytail: folders are flat (immediate parent only), nested hierarchy not preserved.
esc() { echo "replace(replace(replace(replace($1,'&','&amp;'),'<','&lt;'),'>','&gt;'),'\"','&quot;')"; }
sqlite3 -separator $'\t' "$TMP/places.sqlite" \
  "SELECT $(esc "COALESCE(f.title,'')"), $(esc "COALESCE(b.title,p.title,p.url)"), $(esc "p.url")
   FROM moz_bookmarks b
   JOIN moz_places p ON p.id = b.fk
   LEFT JOIN moz_bookmarks f ON f.id = b.parent
   WHERE b.type = 1 AND p.url LIKE 'http%'
   ORDER BY 1, 2;" |
awk -F'\t' '
  BEGIN { print "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n<TITLE>Bookmarks</TITLE>\n<H1>Bookmarks</H1>\n<DL><p>" }
  $1 != cur { if (open) print "    </DL><p>"; cur = $1; open = 1; print "    <DT><H3>" (cur == "" ? "Imported" : cur) "</H3>\n    <DL><p>" }
  { print "        <DT><A HREF=\"" $3 "\">" $2 "</A>"; n++ }
  END { if (open) print "    </DL><p>"; print "</DL><p>" }
' > "$OUT"

echo "Exported $(grep -c '<A HREF' "$OUT") bookmarks -> $OUT"
