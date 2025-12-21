#!/bin/bash

# install_all.sh: Script to execute all installation scripts in apps_installations subdirectory
# Designed for Debian/Ubuntu-based systems

set -e  # Exit on any error

# Function to print informative messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check for bash availability
if ! command -v bash &> /dev/null; then
    log "ERROR: bash is not available. This script requires bash."
    exit 1
fi

# Check for sudo availability
if ! command -v sudo &> /dev/null; then
    log "ERROR: sudo is not available. This script requires sudo for installations."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the apps_installations directory
APPS_DIR="$SCRIPT_DIR/apps_installations"

# Check if apps_installations directory exists
if [ ! -d "$APPS_DIR" ]; then
    log "ERROR: apps_installations directory not found at $APPS_DIR"
    exit 1
fi

log "Starting installation of all apps from $APPS_DIR"

# Run tools_installations if present (idempotent)
TOOLS_DIR="$SCRIPT_DIR/tools_installations"
if [ -d "$TOOLS_DIR" ]; then
    log "Starting tools installation from $TOOLS_DIR"
    TOOLS_SCRIPTS=("$TOOLS_DIR"/*.sh)
    if [ ${#TOOLS_SCRIPTS[@]} -gt 0 ] && [ -f "${TOOLS_SCRIPTS[0]}" ]; then
        for tool_script in "${TOOLS_SCRIPTS[@]}"; do
            if [ -f "$tool_script" ]; then
                tool_name=$(basename "$tool_script")
                log "Processing $tool_name..."
                if [ ! -x "$tool_script" ]; then
                    log "Making $tool_name executable..."
                    chmod +x "$tool_script"
                fi
                log "Executing $tool_name..."
                if bash "$tool_script"; then
                    log "Successfully executed $tool_name"
                else
                    log "ERROR: Failed to execute $tool_name. Stopping execution."
                    exit 1
                fi
            fi
        done
    else
        log "No tool installation scripts found in $TOOLS_DIR"
    fi
else
    log "tools_installations directory not found at $TOOLS_DIR (skipping tools)."
fi

# Get list of all .sh files in apps_installations
INSTALL_SCRIPTS=("$APPS_DIR"/*.sh)

# Check if any scripts were found
if [ ${#INSTALL_SCRIPTS[@]} -eq 0 ] || [ ! -f "${INSTALL_SCRIPTS[0]}" ]; then
    log "ERROR: No installation scripts found in $APPS_DIR"
    exit 1
fi

# Execute each script in sequence
for script in "${INSTALL_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        script_name=$(basename "$script")
        log "Processing $script_name..."

        # Make the script executable if necessary
        if [ ! -x "$script" ]; then
            log "Making $script_name executable..."
            chmod +x "$script"
        fi

        # Run the script with bash
        log "Executing $script_name..."
        if bash "$script"; then
            log "Successfully executed $script_name"
        else
            log "ERROR: Failed to execute $script_name. Stopping execution."
            exit 1
        fi
    fi
done

log "All installation scripts have been executed successfully."