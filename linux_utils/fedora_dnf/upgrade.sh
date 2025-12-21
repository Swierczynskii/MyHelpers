#!/usr/bin/env bash
set -euo pipefail

# Color codes
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_header() {
  local full_text="$1"
  local color="$2"
  local max_len=0

  while IFS= read -r line; do
    local clean_line
    clean_line=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
    local line_len=${#clean_line}
    if (( line_len > max_len )); then
      max_len=$line_len
    fi
  done <<< "$(echo -e "$full_text")"

  local box_width=$((max_len + 4))
  local horizontal_line
  horizontal_line=$(printf '═%.0s' $(seq 1 $box_width))
  echo -e "${color}╔${horizontal_line}╗${NC}"

  while IFS= read -r line; do
    printf "${color}║  ${NC}%-${max_len}s${color}  ║${NC}\n" "$line"
  done <<< "$(echo -e "$full_text")"

  echo -e "${color}╚${horizontal_line}╝${NC}"
}

if ! command -v dnf >/dev/null 2>&1; then
  echo "dnf not found. This script targets Fedora (dnf)."
  exit 1
fi

print_header "Starting the upgrade process (Fedora DNF)!" "$BLUE"

# Refresh metadata and upgrade packages
sudo dnf upgrade --refresh -y
if [ $? -ne 0 ]; then
  echo
  print_header "An error occurred during dnf upgrade --refresh!" "$RED"
  exit 1
fi

# Remove unused packages
sudo dnf autoremove -y
if [ $? -ne 0 ]; then
  echo
  print_header "An error occurred during dnf autoremove!" "$RED"
  exit 1
fi

# Clean caches
sudo dnf clean all -y
if [ $? -ne 0 ]; then
  echo
  print_header "An error occurred during dnf clean all!" "$RED"
  exit 1
fi

echo
print_header "System Update Completed!\nYour Fedora system is now up to date!" "$BLUE"