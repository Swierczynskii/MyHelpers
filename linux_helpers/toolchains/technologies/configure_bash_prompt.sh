#!/usr/bin/env bash
set -euo pipefail
umask 022
# Add or update the MyHelpers prompt block in ~/.bashrc.
# Usable standalone (bash technologies/configure_bash_prompt.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

prompt_block() {
  cat <<'EOF'
# BEGIN MyHelpers prompt
# Show the Git branch in plain text so no special font is needed
parse_git_branch() {
    # Read only HEAD: 'git branch' can run commands configured by an untrusted repo
    local -x GIT_NO_LAZY_FETCH=1
    local ref
    ref="$(git -c safe.bareRepository=explicit symbolic-ref --short -q HEAD 2>/dev/null)" \
      || ref="$(git -c safe.bareRepository=explicit rev-parse --verify -q HEAD 2>/dev/null | cut -c1-7)"
    [ -z "$ref" ] || printf ' (%s)' "$ref"
}

# White for user@host, blue for dir, magenta for branch
if [[ $- == *i* ]]; then
  export PS1="\[\e[1;37m\]\u@\h \[\e[1;34m\]\W\[\e[1;35m\]\$(parse_git_branch)\[\e[0m\]$ "
fi
# END MyHelpers prompt
EOF
}

configure_bash_prompt() {
  local rc="$HOME/.bashrc"
  local BEGIN_MARK="# BEGIN MyHelpers prompt"
  local END_MARK="# END MyHelpers prompt"
  local block current updated

  mkdir -p "$HOME"
  touch "$rc"
  block="$(prompt_block)"

  if ! grep -qsFx "$BEGIN_MARK" "$rc"; then
    # Do not join the block onto a last line without a newline.
    if [[ -n "$(tail -c1 "$rc")" ]]; then
      printf '\n' >> "$rc"
    fi
    printf '%s\n' "$block" >> "$rc"
    log "Added Bash prompt block to $rc"
    return
  fi

  if [[ "$(grep -cFx "$BEGIN_MARK" "$rc")" != 1 || "$(grep -cFx "$END_MARK" "$rc")" != 1 ]]; then
    warn "Bash prompt markers in $rc are incomplete or duplicated; leaving it unchanged."
    return
  fi

  current="$(sed -n "/^${BEGIN_MARK}\$/,/^${END_MARK}\$/p" "$rc")"
  if [[ "$current" == "$block" ]]; then
    log "Bash prompt block already up to date in $rc"
    return
  fi
  if [[ "${current##*$'\n'}" != "$END_MARK" ]]; then
    warn "Bash prompt markers in $rc are out of order; leaving it unchanged."
    return
  fi

  # Replace only the marked block; write through $rc to keep symlinks and permissions.
  updated="$(sed -n "/^${BEGIN_MARK}\$/q;p" "$rc"; printf '%s\n' "$block"; sed "1,/^${END_MARK}\$/d" "$rc"; printf x)"
  printf '%s' "${updated%x}" > "$rc"
  log "Updated Bash prompt block in $rc"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  configure_bash_prompt
fi
