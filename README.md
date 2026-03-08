# MyHelpers

A collection of utility scripts for Windows and Linux to streamline common tasks such as app installation, system upgrades, developer toolchain bootstrapping, display management, network switching, temperatures monitoring, and desktop setup.

## Linux

This repository provides a unified setup flow for Debian/Ubuntu (apt).

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
   - Uses the Debian/Ubuntu backend and selects the matching apps_installations directory
   - Optional: runs backend/tools_installations/install_*.sh first if such directory exists
   - Executes each app installer idempotently; installers skip when the app is already installed
   - Notes: installers must be executable; the orchestrator refuses to chmod executable bits automatically and will exit if a script is not executable

3) Copies an upgrade helper to `$HOME/upgrade.sh` (idempotent)
   - Source file:
     - Debian/Ubuntu: [linux_utils/debian_apt/upgrade.sh](linux_utils/debian_apt/upgrade.sh)

3a) Ensures system monitor helper is available
   - Installs lm-sensors if missing
   - Copies [linux_utils/monitor.sh](linux_utils/monitor.sh) to `$HOME/monitor.sh` and marks it executable (idempotent)
   - Usage after setup: `~/monitor.sh` (tmux split: top + watch sensors; requires lm-sensors, tmux, procps/procps-ng)

3b) Ensures Podman cleanup helper is available
   - Copies [linux_utils/podman_cleanup.sh](linux_utils/podman_cleanup.sh) to `$HOME/podman_cleanup.sh` and marks it executable (idempotent)
   - Always shows a Terraform-like preview before doing anything
   - Default interactive run asks for confirmation, then removes non-running containers and explicitly tries to remove all `<none>:<none>` images
   - `--select` opens a terminal-native `fzf` selector so you can mark any containers and any images to remove
   - In `--select` mode, running containers and tagged images can also be chosen intentionally
   - `fzf` is installed by the bootstrap/setup flow and used as the only selector backend
   - `DRY_RUN=1` shows the preview only and deletes nothing

3c) Configures persistent battery thresholds (best-effort)
   - Uses [linux_utils/battery_thresholds/persistence/install_service.sh](linux_utils/battery_thresholds/persistence/install_service.sh)
   - Interactive prompt:
     - Keep defaults `20%` start and `80%` end
     - Or choose custom start/end values (asked one by one)
   - Non-interactive mode defaults to `20/80`
   - If battery/sysfs support is missing, setup logs a warning and continues

3d) Writes setup log to repository `logs/setup.log`
   - Overwrites on each run (single log file, no log-file buildup)
   - Terminal output is colorized for readability, while the saved log remains plain text

### Requirements
- Debian/Ubuntu with apt
- sudo privileges for system packages are recommended/required for most installers
- Internet access for package and toolchain downloads

### Per-app installers (idempotent)
You can run any installer directly if you don’t want the full bundle.

- Debian/Ubuntu (apt):
  - Brave: [linux_utils/debian_apt/apps_installations/install_brave.sh](linux_utils/debian_apt/apps_installations/install_brave.sh)
  - VS Code: [linux_utils/debian_apt/apps_installations/install_code.sh](linux_utils/debian_apt/apps_installations/install_code.sh)
  - Firefox (APT; removes Snap Firefox if present): [linux_utils/debian_apt/apps_installations/install_firefox.sh](linux_utils/debian_apt/apps_installations/install_firefox.sh)
  - KeePassXC: [linux_utils/debian_apt/apps_installations/install_keepassxc.sh](linux_utils/debian_apt/apps_installations/install_keepassxc.sh)
  - Zed (official installer script): [linux_utils/debian_apt/apps_installations/install_zed.sh](linux_utils/debian_apt/apps_installations/install_zed.sh)
  - Spotify: [linux_utils/debian_apt/apps_installations/install_spotify.sh](linux_utils/debian_apt/apps_installations/install_spotify.sh)
  - VirtualBox: [linux_utils/debian_apt/apps_installations/install_virtualbox.sh](linux_utils/debian_apt/apps_installations/install_virtualbox.sh)

### Manual usage
- Run only the toolchain bootstrap:
  - `bash linux_utils/toolchains/bootstrap_toolchains.sh`
  - Optional: override Node version by exporting `NODE_VERSION` (e.g., `NODE_VERSION=v22.11.0`)
- Run the Podman cleanup helper directly:
  - `./linux_utils/podman_cleanup.sh` to preview safe cleanup and confirm explicit removal of non-running containers plus `<none>:<none>` images
  - `./linux_utils/podman_cleanup.sh --select` to open an `fzf` selector and mark any containers/images to remove, including running containers or tagged images
  - `DRY_RUN=1 ./linux_utils/podman_cleanup.sh` to preview safe cleanup without deleting anything
  - `AUTO_APPROVE=1 ./linux_utils/podman_cleanup.sh` for non-interactive safe cleanup
- Run only the app installers:
  - `bash linux_utils/install_all.sh`
- Force a backend (for testing):
  - `BACKEND=debian_apt bash linux_utils/install_all.sh`

### Intel power modes helpers
Located under [linux_utils/intel](linux_utils/intel):
- README: [linux_utils/intel/README.md](linux_utils/intel/README.md)
- Check current mode: [linux_utils/intel/switches/check_curr_pwr_mode.sh](linux_utils/intel/switches/check_curr_pwr_mode.sh)
- Set best performance: [linux_utils/intel/switches/set_perf_mode.sh](linux_utils/intel/switches/set_perf_mode.sh)
- Set best power efficiency: [linux_utils/intel/switches/set_pwr_eff_mode.sh](linux_utils/intel/switches/set_pwr_eff_mode.sh)

### Battery threshold helpers
Located under [linux_utils/battery_thresholds](linux_utils/battery_thresholds):
- README: [linux_utils/battery_thresholds/README.md](linux_utils/battery_thresholds/README.md)
- Check current thresholds: [linux_utils/battery_thresholds/switches/check_thresholds.sh](linux_utils/battery_thresholds/switches/check_thresholds.sh)
- Set thresholds immediately: [linux_utils/battery_thresholds/switches/set_thresholds.sh](linux_utils/battery_thresholds/switches/set_thresholds.sh)
- Install persistent systemd service: [linux_utils/battery_thresholds/persistence/install_service.sh](linux_utils/battery_thresholds/persistence/install_service.sh)
- Remove persistent systemd service: [linux_utils/battery_thresholds/persistence/uninstall_service.sh](linux_utils/battery_thresholds/persistence/uninstall_service.sh)

Notes:
- All installers are intended to be idempotent and safe to re-run.
- The setup script also ensures the presence of an upgrade helper, a simple temperature monitor script, and a Podman cleanup helper in your home directory.
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
