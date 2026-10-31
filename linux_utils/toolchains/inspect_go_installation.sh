#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# Report the active Go installation and the updater that can safely manage it.
# -----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: inspect_go_installation.sh [--format=human|machine]

Report the active Go binary, its GOROOT, and the detected installation method.

Options:
  --format=human    Display a readable report (default)
  --format=machine  Print only the detected installation type
  -h, --help        Show this help message
EOF
}

FORMAT='human'

while (( $# )); do
  case "$1" in
    --format=human) FORMAT='human' ;;
    --format=machine) FORMAT='machine' ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if ! command -v go >/dev/null 2>&1; then
  if [[ "$FORMAT" == 'machine' ]]; then
    printf '%s\n' 'not-installed'
  else
    printf 'Go installation: not found in PATH\n'
    printf 'Update action: none\n'
  fi
  exit 0
fi

GO_COMMAND="$(command -v go)"
GO_BINARY="$(readlink -f "$GO_COMMAND")"
GO_ROOT="$(go env GOROOT 2>/dev/null || true)"
GO_VERSION="$(go version 2>/dev/null || true)"
INSTALLATION_TYPE='unknown'
UPDATE_ACTION='No automatic update. Use the installation method that originally installed Go.'

if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -S "$GO_BINARY" >/dev/null 2>&1; then
  INSTALLATION_TYPE='apt'
  UPDATE_ACTION='Managed by APT; updated by the apt upgrade phase in ~/upgrade.sh.'
elif [[ "$GO_ROOT" == "$HOME/.local/go" || "$GO_ROOT" == "$HOME/.local/go-"* ]]; then
  INSTALLATION_TYPE='myhelpers-user'
  UPDATE_ACTION='Managed by MyHelpers; ~/upgrade.sh --go updates it.'
elif [[ "$GO_ROOT" == '/usr/local/go' && "$GO_BINARY" == '/usr/local/go/bin/go' ]]; then
  INSTALLATION_TYPE='official-system'
  UPDATE_ACTION='Official system installation; ~/upgrade.sh --go updates it with sudo and retains a rollback backup.'
elif [[ "$GO_COMMAND" == '/snap/bin/go' || "$GO_ROOT" == '/snap/'* ]]; then
  INSTALLATION_TYPE='snap'
  UPDATE_ACTION='Managed by Snap; use snap refresh or wait for its normal refresh schedule.'
fi

if [[ "$FORMAT" == 'machine' ]]; then
  printf '%s\n' "$INSTALLATION_TYPE"
  exit 0
fi

printf 'Go installation: %s\n' "$INSTALLATION_TYPE"
printf 'Command: %s\n' "$GO_COMMAND"
printf 'Binary: %s\n' "$GO_BINARY"
printf 'GOROOT: %s\n' "${GO_ROOT:-unavailable}"
printf 'Version: %s\n' "${GO_VERSION:-unavailable}"
printf 'Update action: %s\n' "$UPDATE_ACTION"
