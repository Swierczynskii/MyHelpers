#!/usr/bin/env bash
# No 'set -e': a failing lookup (e.g. outside a git repo) must not blank the status line.
# Status line derived from the MyHelpers PS1 in ~/.bashrc; installed by install_claude.sh.
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
# Directory and branch names are untrusted; drop control characters before printing.
clean() { printf '%s' "$1" | tr -d '[:cntrl:]'; }
# Read only HEAD: 'git branch' can run commands configured by an untrusted repo.
export GIT_NO_LAZY_FETCH=1
branch=$(git -C "$cwd" -c safe.bareRepository=explicit symbolic-ref --short -q HEAD 2>/dev/null) ||
  branch=$(git -C "$cwd" -c safe.bareRepository=explicit rev-parse --verify -q HEAD 2>/dev/null | cut -c1-7)
# Empty until the first response (and right after /compact).
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty | round')
model=$(echo "$input" | jq -r '.model.display_name // .model.id // empty')
# Absent when the model does not support reasoning effort.
effort=$(echo "$input" | jq -r '.effort.level // empty')
printf '\033[1;37m%s@%s \033[1;34m%s' "$(whoami)" "$(hostname -s)" "$(clean "$(basename "$cwd")")"
[ -n "$branch" ] && printf ' \033[1;35m%s' "$(clean "$branch")"
[ -n "$model" ] && printf ' \033[0;36m%s' "$model"
[ -n "$effort" ] && printf ' \033[0;36m%s' "$effort"
[ -n "$ctx" ] && printf ' \033[0;33mctx %s%%' "$ctx"
printf '\033[0m'
