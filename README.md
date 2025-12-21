# MyHelpers

A collection of utility scripts for Windows and Linux to streamline common tasks such as app installation, system upgrades, display management, network switching, and basic desktop setup.

## Linux (with GNOME)

This repository provides an opinionated setup flow for Debian based Linux with the GNOME desktop.

### Quick start
- Make the setup script executable and run it:
  - `chmod +x ./linux_utils/setup.sh`
  - `./linux_utils/setup.sh`

### What the setup does
- Runs installer bundle: [linux_utils/install_all.sh](linux_utils/install_all.sh)
  - Installs apps from [linux_utils/apps_installation](linux_utils/apps_installation)
  - Each installer is idempotent and skips if the app is already installed
  - Special case: [linux_utils/apps_installation/install_firefox.sh](linux_utils/apps_installation/install_firefox.sh) will detect and remove Snap Firefox (if present) and then install the APT version
- Copies the upgrade helper to your home directory:
  - From [linux_utils/upgrade.sh](linux_utils/upgrade.sh) to `$HOME/upgrade.sh`
  - Re-runnable, won’t overwrite if it already exists
- Sets a wallpaper (best-effort) from [linux_utils/wallpaper](linux_utils/wallpaper)
  - Picks the first supported image (jpg, jpeg, png, bmp, webp) and applies it via GNOME gsettings

### Requirements
- Debian-based Linux (detected via /etc/os-release)
- GNOME desktop (gsettings available with schema org.gnome.desktop.background)
- sudo privileges
- apt package manager

### Per-app installers (idempotent)
You can run any installer directly if you don’t want the full bundle:
- Brave: [linux_utils/apps_installation/install_brave.sh](linux_utils/apps_installation/install_brave.sh)
- VS Code: [linux_utils/apps_installation/install_code.sh](linux_utils/apps_installation/install_code.sh)
- Discord: [linux_utils/apps_installation/install_discord.sh](linux_utils/apps_installation/install_discord.sh)
- Firefox (APT; removes Snap version if present): [linux_utils/apps_installation/install_firefox.sh](linux_utils/apps_installation/install_firefox.sh)
- KeePassXC: [linux_utils/apps_installation/install_keepassxc.sh](linux_utils/apps_installation/install_keepassxc.sh)
- Spotify: [linux_utils/apps_installation/install_spotify.sh](linux_utils/apps_installation/install_spotify.sh)
- VirtualBox: [linux_utils/apps_installation/install_virtualbox.sh](linux_utils/apps_installation/install_virtualbox.sh)

### Upgrade helper
- After running the setup, a convenience script will be available as `$HOME/upgrade.sh` (copied from [linux_utils/upgrade.sh](linux_utils/upgrade.sh))
- Usage: `bash ~/upgrade.sh`

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

