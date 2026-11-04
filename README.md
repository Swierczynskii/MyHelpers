# MyHelpers

A collection of utility scripts for Linux (Debian/Ubuntu) to streamline common tasks such as app installation, system upgrades, developer toolchain bootstrapping, temperatures monitoring, and desktop setup.

## AI

This repository also includes a Claude Code installer: [linux_utils/toolchains/install_claude.sh](linux_utils/toolchains/install_claude.sh) (Bash; Linux, macOS, and WSL).

The installer installs only Claude Code with Anthropic's native installer (skipped when `claude` already exists) and leaves global config, agents, skills, and project-local files untouched.

## Linux

This repository provides a unified setup flow for Debian/Ubuntu (apt).

### Quick start
- Make the setup script executable and run it (installs toolchains, system packages, desktop apps, Podman, Playwright system dependencies, and lm-sensors):
  - `chmod +x ./linux_utils/setup.sh`
  - `./linux_utils/setup.sh`

### What the setup does
1) Bootstraps developer toolchains via [linux_utils/toolchains/bootstrap_toolchains.sh](linux_utils/toolchains/bootstrap_toolchains.sh)
   - Each step is a separate script under [linux_utils/toolchains/technologies](linux_utils/toolchains/technologies) (e.g. `install_mise.sh`, `configure_mise_tools.sh`), sourced by the bootstrap and also runnable on its own: `bash linux_utils/toolchains/technologies/configure_mise_tools.sh`; shared helpers live in `common.sh`
   - mise (installed first, from its signed APT repository with a pinned key fingerprint; `mise activate` is added to `~/.bashrc` and `~/.zshrc` unless an activation already exists)
   - Global toolchains via mise (`mise use --global`, recorded in `~/.config/mise/config.toml`): Node.js LTS (follows each new LTS line automatically), pnpm, Go, Rust stable (through rustup), Bun, uv, sqlite3def (sqldef, MIT: declarative SQLite schema from plain SQL files incl. views and triggers: `sqlite3def app.db --dry-run < schema.sql`, then `--apply`)
   - mise shims are added to `~/.profile` (and an existing `~/.bash_profile`) so non-interactive shells, scripts, and GUI apps find the tools too
   - Python is not managed by mise: use uv (`uv python install`, `.python-version`, `pyproject.toml`)
   - Per-project versions: run `mise use <tool>@<version>` inside a repo to write its own `mise.toml`, which overrides the global defaults there (mise asks you to `mise trust` it once). `.nvmrc`/`.node-version` are read only after `mise settings add idiomatic_version_file_enable_tools node`
   - Playwright (installed globally from npm, then browser binaries are installed for the user)
   - Podman, tmux, fzf, procps/top, apt prerequisites, and Playwright Linux deps are installed via apt
   - Sets the default GNOME Terminal profile to 8% transparency when GNOME Terminal settings are available; override with `GNOME_TERMINAL_TRANSPARENCY` (0–100)

1a) Installs Claude Code via [linux_utils/toolchains/install_claude.sh](linux_utils/toolchains/install_claude.sh) (Anthropic official installer)

2) Runs the app installer orchestrator inline from [linux_utils/setup.sh](linux_utils/setup.sh)
   - Uses the Debian/Ubuntu backend and selects the matching apps_installations directory
   - Optional: runs backend/tools_installations/install_*.sh first if such directory exists
   - Executes each app installer idempotently; installers skip when the app is already installed
   - Notes: installers must be executable; the orchestrator refuses to chmod executable bits automatically and will exit if a script is not executable

3) Copies upgrade helpers to `$HOME` (idempotent)
   - Source file:
     - Debian/Ubuntu: [linux_utils/debian_apt/upgrade.sh](linux_utils/debian_apt/upgrade.sh)
   - `~/upgrade.sh` runs the apt steps (which also update mise itself); add `--mise` for `mise upgrade` (Node.js, pnpm, Go, Bun, uv, sqlite3def), `--rust` for `rustup update`, `--claude` for Claude Code, or `--all` for everything

3a) Ensures system monitor helper is available
   - Installs lm-sensors if missing
   - Copies [linux_utils/monitor.sh](linux_utils/monitor.sh) to `$HOME/monitor.sh` and marks it executable (idempotent)
   - Usage after setup: `~/monitor.sh` (tmux split: top + watch sensors; requires lm-sensors, tmux, procps/procps-ng)

3b) Ensures Podman cleanup helper is available
   - Copies [linux_utils/podman_cleanup.sh](linux_utils/podman_cleanup.sh) to `$HOME/podman_cleanup.sh` and marks it executable (idempotent)
   - Always shows a Terraform-like preview before doing anything
   - Default interactive run asks for confirmation, then removes non-running containers and explicitly tries to remove all `<none>:<none>` images
   - `-s` / `--select` opens a terminal-native `fzf` selector so you can mark any containers and any images to remove; Enter with nothing marked skips that step (containers or images), so you can remove only one kind; the focused row is never picked implicitly
   - In `--select` mode, running containers and tagged images can also be chosen intentionally
   - `fzf` is installed by the bootstrap/setup flow and used as the only selector backend
   - `DRY_RUN=1` shows the preview only and deletes nothing

3c) Configures a macOS-like close-window shortcut (best-effort)
   - Setup runs [linux_utils/macos_quit_shortcut.sh](linux_utils/macos_quit_shortcut.sh) directly; it is not copied to `$HOME`
   - On GNOME, it replaces the default `Alt+F4` close-window shortcut with `Super+Q`, the closest Linux equivalent to macOS `Command+Q`
   - Before assigning it, setup clears an existing single `Super+Q` shortcut so a competing GNOME component such as Ubuntu Dock cannot capture it
   - It closes the current app window; applications with multiple windows may remain open

3d) Writes setup log to repository `logs/setup.log`
   - Overwrites on each run (single log file, no log-file buildup)
   - Terminal output is colorized for readability, while the saved log remains plain text with terminal control sequences stripped
   - Major setup and installer phases use boxed terminal headers again for easier scanning

### Requirements
- Debian/Ubuntu with apt
- Run setup scripts as your normal user; do not run them with `sudo`
- sudo privileges are required for the system steps of setup and when running apt/system installers directly
- Internet access for package and toolchain downloads

### Per-app installers (idempotent)
You can run any installer directly if you don’t want the full bundle.

- Debian/Ubuntu (apt):
  - Brave: [linux_utils/debian_apt/apps_installations/install_brave.sh](linux_utils/debian_apt/apps_installations/install_brave.sh)
  - VS Code: [linux_utils/debian_apt/apps_installations/install_code.sh](linux_utils/debian_apt/apps_installations/install_code.sh)
  - VSCodium (official VSCodium APT repository; amd64/arm64; installs `codium`): [linux_utils/debian_apt/apps_installations/install_codium.sh](linux_utils/debian_apt/apps_installations/install_codium.sh)
  - Google Chrome: [linux_utils/debian_apt/apps_installations/install_google_chrome.sh](linux_utils/debian_apt/apps_installations/install_google_chrome.sh)
  - KeePassXC: [linux_utils/debian_apt/apps_installations/install_keepassxc.sh](linux_utils/debian_apt/apps_installations/install_keepassxc.sh)
  - LibreWolf (via `extrepo`; also removes Snap Firefox if present, purging its Snap profile data): [linux_utils/debian_apt/apps_installations/install_librewolf.sh](linux_utils/debian_apt/apps_installations/install_librewolf.sh)
  - pgAdmin 4 (official pgAdmin APT repository; asks for web, desktop, or both, and offers the missing variant if one is already installed): [linux_utils/debian_apt/apps_installations/install_pgadmin.sh](linux_utils/debian_apt/apps_installations/install_pgadmin.sh)
  - Signal Desktop (official Signal APT repository; amd64 only): [linux_utils/debian_apt/apps_installations/install_signal.sh](linux_utils/debian_apt/apps_installations/install_signal.sh)
  - Wireshark (apt package): [linux_utils/debian_apt/apps_installations/install_wireshark.sh](linux_utils/debian_apt/apps_installations/install_wireshark.sh)
  - Raspberry Pi Imager (apt package `rpi-imager`): [linux_utils/debian_apt/apps_installations/install_rpi_imager.sh](linux_utils/debian_apt/apps_installations/install_rpi_imager.sh)
  - KVM + virt-manager (qemu, libvirt, OVMF; adds you to `libvirt`/`kvm` groups, re-login needed): [linux_utils/debian_apt/apps_installations/install_virt_manager.sh](linux_utils/debian_apt/apps_installations/install_virt_manager.sh)

### Manual usage
- Run only the toolchain bootstrap:
  - `bash linux_utils/toolchains/bootstrap_toolchains.sh`
  - Add `-s` (or `--system`) to install apt prerequisites, mise, Podman, terminal helpers, and Playwright system dependencies
  - Without `--system`, mise must already be installed
  - Change global versions with `mise use --global node@<major>` (etc.); list them with `mise ls --global`
  - Optional: verify installed toolchains with `mise doctor`, `node -v`, `pnpm -v`, `bun --version`, `rustc --version`, `go version`, `uv --version`, `sqlite3def --version`, `playwright --version`, and `podman --version`
- Run only the Claude Code installer:
  - `bash linux_utils/toolchains/install_claude.sh`
- Run the Podman cleanup helper directly:
  - `./linux_utils/podman_cleanup.sh` to preview safe cleanup and confirm explicit removal of non-running containers plus `<none>:<none>` images
  - `./linux_utils/podman_cleanup.sh -s` (or `--select`) to open an `fzf` selector and mark any containers/images to remove, including running containers or tagged images
  - `DRY_RUN=1 ./linux_utils/podman_cleanup.sh` to preview safe cleanup without deleting anything
  - `AUTO_APPROVE=1 ./linux_utils/podman_cleanup.sh` for non-interactive safe cleanup
- Run system app installers through setup:
  - `./linux_utils/setup.sh`
- Run an individual app installer directly:
  - `bash linux_utils/debian_apt/apps_installations/install_code.sh`

Notes:
- All installers are intended to be idempotent and safe to re-run.
- The setup script also ensures the presence of an upgrade helper, a simple temperature monitor script, and a Podman cleanup helper in your home directory.
- The orchestrator enforces executability for install scripts and will stop if a script is not executable to avoid unintended permission changes.
