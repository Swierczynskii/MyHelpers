#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_helpers/init_repository.sh
# Set up the current folder as a repository with mise-pinned tk tickets and AGENTS.md.
# Deployed by setup.sh as ~/.local/bin/init-repository. Existing files are never overwritten.
# -----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: init-repository [-h|--help]

Sets up the current folder (which must be a repository root or not in a repository):
  - git init (branch main) when it is not a repository yet
  - mise.toml pinning tk (https://github.com/wedow/ticket), AGENTS.md with the ticket workflow
  - .tickets/ and .worktrees/, both added to .gitignore
  - mise trust + install of tk
  - initial commit of the setup files, only in a repository it just created

Existing mise.toml and AGENTS.md are kept. Safe to re-run.
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

present() { [[ -e "$1" || -L "$1" ]]; }

mise_toml() {
  cat <<'EOF'
# Project tools. Run `mise trust && mise install` after cloning.

[tools."http:tk"]
# https://github.com/wedow/ticket (single bash script, no release binaries)
# When bumping the version, update the checksum too.
version = "0.3.2"
url = "https://raw.githubusercontent.com/wedow/ticket/v{{ version }}/ticket"
checksum = "sha256:408f2c113ecc3bc071507593a78386f1b4cc743be6491c9e9f2627efd4d9902b"
bin = "tk"
EOF
}

agents_md() {
  cat <<'EOF'
# AGENTS.md

## Workflow

Work is tracked with `tk` tickets (stored in `.tickets/`, **not git-tracked**; see `tk help`).

1. **Pick a ticket**: `tk ready`, then `tk show <id>` and `tk start <id>`.
   No ticket for the work? `tk create "title"` first.
   **Exception:** "meta" tasks (e.g. rethinking the backlog) need no ticket; just proceed.
2. **One ticket = one worktree + branch**, never work on `main` directly:
   `git worktree add .worktrees/<id> -b <id> main`
   Run this from the repo root. Several agents may work at once, so stay in your own worktree.
3. **Implement** inside that worktree. Small, focused commits.
4. **Finish**: `tk close <id>`, then keep history linear. Rebase onto `main` and fast-forward merge:
   ```
   git -C .worktrees/<id> rebase main
   git merge --ff-only <id>        # run from the main worktree
   ```
   No merge commits. Squash/fixup noise commits during the rebase.
5. **Clean up**: `git worktree remove .worktrees/<id> && git branch -d <id>`.

## Rules
- Don't commit `.tickets/`.
- Don't merge or push without the user's go-ahead.
- Found unrelated work? `tk create` a new ticket, don't widen the current one.
EOF
}

# $1: file, $2: function printing its content
write_if_missing() {
  if present "$1"; then
    log "Keeping existing $1"
    return 1
  fi
  "$2" > "$1"
  CREATED+=("$1")
  log "Created $1"
}

ignore_entry() {
  if grep -Fqxs -- "$1" .gitignore; then
    return
  fi
  # Do not join the entry onto a last line without a newline.
  if [[ -s .gitignore && -n "$(tail -c1 .gitignore)" ]]; then
    printf '\n' >> .gitignore
  fi
  printf '%s\n' "$1" >> .gitignore
  log "Added $1 to .gitignore"
}

# Trusting covers every mise config in the folder, so only do it when ours is the only one.
other_mise_config() {
  local file
  for file in .mise.toml mise.*.toml .mise.*.toml mise .mise .config/mise .config/mise.toml .tool-versions; do
    if present "$file"; then
      return 0
    fi
  done
  return 1
}

install_tk() {
  if ! command -v mise >/dev/null 2>&1; then
    warn "mise not found; install it, then run: mise trust && mise install"
  elif ! cmp -s mise.toml <(mise_toml) || other_mise_config; then
    warn "This folder has its own mise config, so it was not trusted automatically. Review it (tk needs the [tools.\"http:tk\"] entry), then run: mise trust && mise install"
  elif mise trust --quiet "$PWD/mise.toml" && mise install http:tk; then
    log "tk installed"
  else
    warn "Could not install tk; run: mise trust && mise install"
  fi
}

case "${1:-}" in
  '') ;;
  -h|--help) usage; exit 0 ;;
  *) err "Unknown option: $1"; usage >&2; exit 1 ;;
esac

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  err "Run this without sudo."
  exit 1
fi
if [[ "$PWD" -ef "$HOME" || "$PWD" == / ]]; then
  err "Refusing to turn $PWD into a repository; cd into a project folder first."
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  err "Required command not found: git"
  exit 1
fi

CREATED=()
NEW_REPO=0
if git rev-parse --git-dir >/dev/null 2>&1; then
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -z "$top" || ! "$top" -ef "$PWD" ]]; then
    err "This folder is inside another repository (${top:-a bare or .git directory}); run this from a repository root."
    exit 1
  fi
  log "Already a Git repository; keeping it."
elif present .git; then
  err ".git exists but Git cannot use it; run 'git status' for the reason."
  exit 1
else
  git init -q -b main
  NEW_REPO=1
  log "Initialized Git repository (branch main)"
fi

write_if_missing mise.toml mise_toml || true
write_if_missing AGENTS.md agents_md || true
ignore_entry .tickets/
ignore_entry .worktrees/
# tk looks for .tickets/ in parent folders, so worktrees share this one.
mkdir -p .tickets .worktrees
install_tk

branch="$(git symbolic-ref --short -q HEAD || true)"
if [[ "$branch" != main ]]; then
  warn "Current branch is '${branch:-detached}', but the AGENTS.md workflow assumes 'main'."
fi

if (( NEW_REPO )); then
  git add -- .gitignore ${CREATED[@]+"${CREATED[@]}"}
  if git commit -q -m "Initial commit: repository setup"; then
    log "Committed the setup files"
  else
    warn "Could not commit; the setup files are staged. Commit them before creating worktrees."
  fi
else
  log "Review and commit the changes: git status"
fi
