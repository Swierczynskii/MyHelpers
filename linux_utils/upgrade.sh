#!/bin/bash

# Color codes
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_header() {
    local full_text="$1"
    local color="$2"
    local max_len=0

    while IFS= read -r line; do
        local clean_line=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
        local line_len=${#clean_line}
        if (( line_len > max_len )); then
            max_len=$line_len
        fi
    done <<< "$(echo -e "$full_text")" # Use echo -e to process \n for the loop

    local box_width=$((max_len + 4))
    local horizontal_line
    horizontal_line=$(printf '═%.0s' $(seq 1 $box_width))
    echo -e "${color}╔${horizontal_line}╗${NC}"

    while IFS= read -r line; do
        printf "${color}║  ${NC}%-${max_len}s${color}  ║${NC}\n" "$line"
    done <<< "$(echo -e "$full_text")"

    echo -e "${color}╚${horizontal_line}╝${NC}"
}

print_header "Starting the upgrade process!" "$BLUE"

sudo apt update
if [ $? -ne 0 ]; then
    echo
    print_header "An error occurred during apt update!" "$RED"
    exit 1
fi

sudo apt upgrade -y 
if [ $? -ne 0 ]; then
    echo
    print_header "An error occurred during apt upgrade!" "$RED"
    exit 1
fi

sudo apt autoremove -y
if [ $? -ne 0 ]; then
    echo
    print_header "An error occurred during apt autoremove!" "$RED"
    exit 1
fi

echo
print_header "Update and Upgrade Completed!\nYour system is now up to date!" "$BLUE"