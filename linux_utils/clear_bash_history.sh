#!/usr/bin/env bash
# Sourced (`. ~/clear_bash_history.sh --session`) must not alter the caller's shell options.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then set -euo pipefail; fi
umask 022
# -----------------------------------------------------------------------------
# linux_utils/clear_bash_history.sh
# Clears bash history leftovers. Does nothing without an option.
# -----------------------------------------------------------------------------

_cbh_usage() {
  cat <<'USAGE'
Usage: clear_bash_history.sh [options]

  --orphans   Remove orphaned ~/.bash_history-*.tmp files
  --file      Empty ~/.bash_history
  --session   Clear the current shell session's history (in-memory);
              only works when sourced: . clear_bash_history.sh --session
  --all       --orphans + --file (+ --session when sourced)
  -h, --help  Show this help

Tip: history is rewritten from memory on shell exit; run --session
(sourced) together with --file, or the open shell may restore old entries.
USAGE
}

_cbh_main() {
  local orphans=0 file=0 session=0 sourced=0
  [[ "${BASH_SOURCE[0]}" != "$0" ]] && sourced=1
  (( $# )) || { _cbh_usage; return 0; }
  while (( $# )); do
    case "$1" in
      --orphans) orphans=1 ;;
      --file) file=1 ;;
      --session) session=1 ;;
      --all) orphans=1 file=1 session=$sourced ;;
      -h|--help) _cbh_usage; return 0 ;;
      *) echo "Unknown option: $1" >&2; _cbh_usage >&2; return 1 ;;
    esac
    shift
  done

  if (( orphans )); then
    shopt -s nullglob
    local f n=0
    for f in "$HOME"/.bash_history-*.tmp; do rm -f -- "$f"; n=$((n + 1)); done
    shopt -u nullglob
    echo "Removed $n orphaned temp file(s)."
  fi
  if (( file )); then
    : > "$HOME/.bash_history"
    echo "Emptied ~/.bash_history."
  fi
  if (( session )); then
    if (( sourced )); then
      history -c
      echo "Cleared current session history."
    else
      echo "--session needs sourcing: . $0 --session" >&2
      return 1
    fi
  fi
}

_cbh_main "$@"
_cbh_rc=$?
unset -f _cbh_main _cbh_usage
(return 0 2>/dev/null) && { unset _cbh_rc; true; } || exit "$_cbh_rc"
