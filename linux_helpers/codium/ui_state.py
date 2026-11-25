#!/usr/bin/env python3
"""Export/import VSCodium layout state: ui_state.py export|import <state.vscdb> <ui_state.json>"""
import json
import sqlite3
import sys

# Layout only: state.vscdb also holds tokens, history and paths, so never copy it whole.
KEYS = [
    "workbench.activity.pinnedViewlets2",
    "workbench.panel.pinnedPanels",
    "workbench.auxiliarybar.pinnedPanels",
    "workbench.explorer.views.state.hidden",
    "workbench.scm.views.state.hidden",
    "workbench.view.extensions.state.hidden",
    "workbench.statusbar.hidden",
    "workbench.sideBar.size",
    "workbench.panel.size",
    "workbench.panel.alignment",
    "workbench.auxiliaryBar.size",
]


def export_state(db_path, json_path):
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    state = {}
    for key in KEYS:
        row = db.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
        if row:
            value = row[0].decode() if isinstance(row[0], bytes) else str(row[0])
            # JSON values are stored decoded so diffs stay readable.
            state[key] = json.loads(value) if value[:1] in "[{" else value
    with open(json_path, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")


def import_state(db_path, json_path):
    with open(json_path) as f:
        state = json.load(f)
    db = sqlite3.connect(db_path)
    with db:
        db.execute("CREATE TABLE IF NOT EXISTS ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB)")
        if db.execute("PRAGMA user_version").fetchone()[0] == 0:
            db.execute("PRAGMA user_version = 1")
        for key in KEYS:
            if key in state:
                value = state[key]
                if not isinstance(value, str):
                    value = json.dumps(value, separators=(",", ":"))
                db.execute("INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)", (key, value))


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in ("export", "import"):
        sys.exit(__doc__)
    (export_state if sys.argv[1] == "export" else import_state)(sys.argv[2], sys.argv[3])
