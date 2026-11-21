#!/usr/bin/env bash
set -euo pipefail
umask 022
# Add the MyHelpers prompt block to ~/.bashrc.
# Usable standalone (bash technologies/configure_bash_prompt.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

configure_bash_prompt() {
  local rc="$HOME/.bashrc"
  local BEGIN_MARK="# BEGIN MyHelpers prompt"

  mkdir -p "$HOME"
  touch "$rc"

  if grep -qs "^${BEGIN_MARK}$" "$rc"; then
    log "Bash prompt block already present in $rc"
    return
  fi

  tee -a "$rc" >/dev/null <<'EOF'
# BEGIN MyHelpers prompt
# Parse Git branch nicely with a branch symbol
parse_git_branch() {
    git branch --no-color 2>/dev/null \
      | sed -n '/\* /s///p' \
      | sed -E 's/(.*)/ \1/'
}

# White for user@host, blue for dir, magenta for branch
if [[ $- == *i* ]]; then
  export PS1="\[\e[1;37m\]\u@\h \[\e[1;34m\]\W \[\e[1;35m\]\$(parse_git_branch)\[\e[0m\]$ "
fi
# END MyHelpers prompt
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  configure_bash_prompt
fi
