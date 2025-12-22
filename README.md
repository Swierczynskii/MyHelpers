# MyHelpers

A collection of utility scripts for Windows and Linux to streamline common tasks such as app installation, system upgrades, developer toolchain bootstrapping, display management, network switching, temperatures monitoring, and desktop setup.

## Linux

This repository provides a unified setup flow for Debian/Ubuntu (apt) and Fedora (dnf). GNOME wallpaper configuration is supported on systems where gsettings and the org.gnome.desktop.background schema are available.

### Quick start
- Make the setup script executable and run it:
  - `chmod +x ./linux_utils/setup.sh`
  - `./linux_utils/setup.sh`

### What the setup does
1) Bootstraps developer toolchains via [linux_utils/toolchains/bootstrap_toolchains.sh](linux_utils/toolchains/bootstrap_toolchains.sh)
   - Node.js (installed via official tarball; Corepack enabled and pnpm activated)
   - uv (Astral official installer)
   - Adds the necessary PATH entries idempotently to your shell profiles

2) Runs the unified app installer orchestrator: [linux_utils/install_all.sh](linux_utils/install_all.sh)
   - Automatically detects the backend (apt vs dnf) and selects the matching apps_installations directory
   - Optional: runs backend/tools_installations/install_*.sh first if such directory exists
   - Fedora only: if present, runs [linux_utils/fedora_dnf/apps_installations/install_flatpak.sh](linux_utils/fedora_dnf/apps_installations/install_flatpak.sh) once before the rest of the apps, then skips it in the main loop
   - Executes each app installer idempotently; installers skip when the app is already installed
   - Notes: installers must be executable; the orchestrator refuses to chmod executable bits automatically and will exit if a script is not executable

3) Copies an upgrade helper to `$HOME/upgrade.sh` (idempotent)
   - Source file depends on your backend:
     - Debian/Ubuntu: [linux_utils/debian_apt/upgrade.sh](linux_utils/debian_apt/upgrade.sh)
     - Fedora: [linux_utils/fedora_dnf/upgrade.sh](linux_utils/fedora_dnf/upgrade.sh)

3a) Ensures temperature monitoring helper is available
   - Installs lm-sensors if missing
   - Copies [linux_utils/temps.sh](linux_utils/temps.sh) to `$HOME/temps.sh` and marks it executable (idempotent)
   - Usage after setup: `~/temps.sh` (live watch of sensors output, requires lm-sensors)

4) Sets a wallpaper (best-effort) from [linux_utils/wallpaper](linux_utils/wallpaper)
   - Picks the first supported image (jpg, jpeg, png, bmp, webp)
   - Applies it via GNOME gsettings (if available)
   - Prompts interactively for GNOME picture-options (default: zoom)

### Requirements
- One of:
  - Debian/Ubuntu with apt
  - Fedora with dnf
- sudo privileges for system packages are recommended/required for most installers
- GNOME desktop only required for wallpaper step (gsettings + org.gnome.desktop.background)
- Internet access for package and toolchain downloads

### Per-app installers (idempotent)
You can run any installer directly if you don’t want the full bundle.

- Debian/Ubuntu (apt):
  - Brave: [linux_utils/debian_apt/apps_installations/install_brave.sh](linux_utils/debian_apt/apps_installations/install_brave.sh)
  - VS Code: [linux_utils/debian_apt/apps_installations/install_code.sh](linux_utils/debian_apt/apps_installations/install_code.sh)
  - Discord: [linux_utils/debian_apt/apps_installations/install_discord.sh](linux_utils/debian_apt/apps_installations/install_discord.sh)
  - Firefox (APT; removes Snap Firefox if present): [linux_utils/debian_apt/apps_installations/install_firefox.sh](linux_utils/debian_apt/apps_installations/install_firefox.sh)
  - KeePassXC: [linux_utils/debian_apt/apps_installations/install_keepassxc.sh](linux_utils/debian_apt/apps_installations/install_keepassxc.sh)
  - Spotify: [linux_utils/debian_apt/apps_installations/install_spotify.sh](linux_utils/debian_apt/apps_installations/install_spotify.sh)
  - VirtualBox: [linux_utils/debian_apt/apps_installations/install_virtualbox.sh](linux_utils/debian_apt/apps_installations/install_virtualbox.sh)

- Fedora (dnf):
  - Brave: [linux_utils/fedora_dnf/apps_installations/install_brave.sh](linux_utils/fedora_dnf/apps_installations/install_brave.sh)
  - VS Code: [linux_utils/fedora_dnf/apps_installations/install_code.sh](linux_utils/fedora_dnf/apps_installations/install_code.sh)
  - Discord: [linux_utils/fedora_dnf/apps_installations/install_discord.sh](linux_utils/fedora_dnf/apps_installations/install_discord.sh)
  - Firefox (dnf, with Flatpak fallback): [linux_utils/fedora_dnf/apps_installations/install_firefox.sh](linux_utils/fedora_dnf/apps_installations/install_firefox.sh)
  - Flatpak bootstrap: [linux_utils/fedora_dnf/apps_installations/install_flatpak.sh](linux_utils/fedora_dnf/apps_installations/install_flatpak.sh)
  - KeePassXC: [linux_utils/fedora_dnf/apps_installations/install_keepassxc.sh](linux_utils/fedora_dnf/apps_installations/install_keepassxc.sh)
  - Spotify: [linux_utils/fedora_dnf/apps_installations/install_spotify.sh](linux_utils/fedora_dnf/apps_installations/install_spotify.sh)
  - VirtualBox: [linux_utils/fedora_dnf/apps_installations/install_virtualbox.sh](linux_utils/fedora_dnf/apps_installations/install_virtualbox.sh)

### Manual usage
- Run only the toolchain bootstrap:
  - `bash linux_utils/toolchains/bootstrap_toolchains.sh`
  - Optional: override Node version by exporting `NODE_VERSION` (e.g., `NODE_VERSION=v22.11.0`)
- Run only the app installers (auto-detects backend):
  - `bash linux_utils/install_all.sh`
- Force a backend (for testing):
  - `BACKEND=debian_apt bash linux_utils/install_all.sh`
  - `BACKEND=fedora_dnf bash linux_utils/install_all.sh`
- Intel power modes helpers (see below) can be executed directly

### Intel power modes helpers
Located under [linux_utils/intel](linux_utils/intel):
- README: [linux_utils/intel/README.md](linux_utils/intel/README.md)
- Check current mode: [linux_utils/intel/switches/check_curr_pwr_mode.sh](linux_utils/intel/switches/check_curr_pwr_mode.sh)
- Set best performance: [linux_utils/intel/switches/set_perf_mode.sh](linux_utils/intel/switches/set_perf_mode.sh)
- Set best power efficiency: [linux_utils/intel/switches/set_pwr_eff_mode.sh](linux_utils/intel/switches/set_pwr_eff_mode.sh)

Notes:
- These helpers call tuned-adm profiles from Intel's EPP Tuning package and are intended for Intel Ultra Mobile CPUs as per Intel's documentation.
- Prerequisites: `tuned-adm` and Intel EPP profiles installed and available on your system.
- You may need to run them with elevated privileges (e.g., via sudo) depending on your tuned configuration.

### Notes
- All installers are intended to be idempotent and safe to re-run.
- Fedora’s Flatpak environment is prepared once (if the bootstrap script is present) and then excluded from the main pass.
- The setup script also ensures the presence of an upgrade helper and a simple temperature monitor script in your home directory, and sets wallpaper on GNOME when possible.
- The orchestrator enforces executability for install scripts and will stop if a script is not executable to avoid unintended permission changes.

## Windows

### Features

- Display Management
  - [win_utils/ExtendDisplay.bat](win_utils/ExtendDisplay.bat): Extend to multiple displays
  - [win_utils/FirstDisplay.bat](win_utils/FirstDisplay.bat): Primary display only
  - [win_utils/SecondDisplay.bat](win_utils/SecondDisplay.bat): Secondary display only

- Network Management
  - [win_utils/NetworkInterfaceSwitch.ps1](win_utils/NetworkInterfaceSwitch.ps1): PowerShell script to enable/disable adapters by name
  - [win_utils/SwitchToEthernet.bat](win_utils/SwitchToEthernet.bat): Enables Ethernet, disables Wi‑Fi
  - [win_utils/SwitchToWiFi.bat](win_utils/SwitchToWiFi.bat): Enables Wi‑Fi, disables Ethernet

### Windows requirements and notes
- Windows 11
- PowerShell 5.1 or later
- Administrative privileges required for network adapter changes
- Determine your adapter names with `Get-NetAdapter` and adjust batch arguments if they differ from Wi‑Fi/Ethernet defaults
