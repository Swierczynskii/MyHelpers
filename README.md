# MyHelpers

A collection of utility scripts for Linux (Debian/Ubuntu) to streamline common tasks such as app installation, system upgrades, developer toolchain bootstrapping, temperatures monitoring, and desktop setup.

## AI

This repository also includes a Claude Code installer: [linux_helpers/toolchains/install_claude.sh](linux_helpers/toolchains/install_claude.sh) (Bash; Linux, macOS, and WSL).

The installer installs Claude Code with Anthropic's native installer (skipped when `claude` already exists) and sets up a status line showing `user@host`, directory, Git branch, model, reasoning effort, and context usage.

The status line needs `jq` (skipped with a warning if missing). It copies [claude_statusline.sh](linux_helpers/toolchains/claude_statusline.sh) to `~/.claude/statusline-command.sh` and adds `statusLine` to `~/.claude/settings.json`; an existing custom status line is kept, and re-runs overwrite edits to the copied script. Other global config, agents, skills, and project-local files are left untouched.

## Linux

This repository provides a unified setup flow for Debian/Ubuntu (apt).

### Requirements
- **amd64 (x86_64) only. ARM (arm64/armhf) is untested and not supported for now**, even though some scripts do not refuse to run there.
- Debian/Ubuntu with apt
- Run setup scripts as your normal user; do not run them with `sudo`
- sudo privileges are required for the system steps of setup and when running apt/system installers directly
- Internet access for package and toolchain downloads

### Quick start
- Make the setup script executable and run it (installs toolchains, system packages, desktop apps, Podman, lm-sensors, and smartmontools):
  - `chmod +x ./linux_helpers/setup.sh`
  - `./linux_helpers/setup.sh`

### What the setup does
1) Bootstraps developer toolchains via [linux_helpers/toolchains/bootstrap_toolchains.sh](linux_helpers/toolchains/bootstrap_toolchains.sh)
   - Each step is a separate script under [linux_helpers/toolchains/technologies](linux_helpers/toolchains/technologies) (e.g. `install_mise.sh`, `configure_mise_tools.sh`), sourced by the bootstrap and also runnable on its own: `bash linux_helpers/toolchains/technologies/configure_mise_tools.sh`; shared helpers live in `common.sh`
   - mise (installed first, from its signed APT repository with a pinned key fingerprint; `mise activate` is added to `~/.bashrc` and `~/.zshrc` unless an activation already exists)
   - Global toolchains via mise (`mise use --global`, recorded in `~/.config/mise/config.toml`; only tools absent from your global config are added, versions you already set are kept, and configured tools that are not installed yet are installed): Node.js LTS (follows each new LTS line automatically), pnpm, Go, Rust stable (through rustup), Bun, uv, Java (Temurin 21), coursier (`cs`), sqlite3def (sqldef, MIT: declarative SQLite schema from plain SQL files incl. views and triggers: `sqlite3def app.db --dry-run < schema.sql`, then `--apply`)
   - Scala via Coursier (`install_scala.sh`): `scala`, `scalac`, `sbt`, `scalafmt`, `metals` installed with `cs install` into `~/.local/share/coursier/bin` (added to PATH); they run on the mise-managed Java, so no system Java is needed. Add more with `cs install <app>`
   - mise shims and `JAVA_HOME` (the installed global mise Java; an existing `JAVA_HOME` line is kept, so update it yourself if you change the global Java; the added line applies only when `JAVA_HOME` is unset, so per-project versions win) are added to `~/.profile` (and an existing `~/.bash_profile`) so non-interactive shells, scripts, and GUI apps find the tools too
   - Python is not managed by mise: use uv (`uv python install`, `.python-version`, `pyproject.toml`)
   - Per-project versions: run `mise use <tool>@<version>` inside a repo to write its own `mise.toml`, which overrides the global defaults there (mise asks you to `mise trust` it once). `.nvmrc`/`.node-version` are read only after `mise settings add idiomatic_version_file_enable_tools node`
   - Podman, tmux, fzf, procps/top, and apt prerequisites (including ShellCheck) are installed via apt
   - Podman, not Docker, is the primary container engine: when setup installs Podman it also installs `podman-docker`, which provides a Docker-compatible `docker` command. It conflicts with Docker's packages and replaces them if present (logged)
   - Adds a Bash prompt with the current Git branch, e.g. `(main)`, to `~/.bashrc`; re-runs update the marked block, so edits inside it are overwritten
   - Sets the default Ptyxis and/or GNOME Terminal profile to 8% transparency when their settings are available; override with `GNOME_TERMINAL_TRANSPARENCY` (0–100)

1a) Installs Claude Code via [linux_helpers/toolchains/install_claude.sh](linux_helpers/toolchains/install_claude.sh) (Anthropic official installer) and configures its status line

2) Runs the app installer orchestrator inline from [linux_helpers/setup.sh](linux_helpers/setup.sh)
   - Uses the Debian/Ubuntu backend and selects the matching apps_installations directory
   - Optional: runs backend/tools_installations/install_*.sh first if such directory exists
   - Executes each app installer idempotently; installers skip when the app is already installed
   - Notes: installers must be executable; the orchestrator refuses to chmod executable bits automatically and counts a non-executable script as failed
   - A failed installer does not stop the others; failures are listed at the end and setup exits with code 1

3) Copies upgrade helpers to `$HOME` (idempotent)
   - Source file:
     - Debian/Ubuntu: [linux_helpers/debian_apt/upgrade.sh](linux_helpers/debian_apt/upgrade.sh)
   - `~/upgrade.sh` runs the apt steps (which also update mise itself); add `--mise` for `mise upgrade` (Node.js, pnpm, Go, Bun, uv, sqlite3def), `--rust` for `rustup update`, `--scala` for `cs update` (Coursier apps: scala, sbt, metals, ...), `--claude` for Claude Code, or `--all` for everything

3a) Ensures system monitor helper is available
   - Installs lm-sensors and smartmontools if missing (smartmontools without recommended mail packages; check a disk with `sudo smartctl -a /dev/<disk>`)
   - Copies [linux_helpers/monitor.sh](linux_helpers/monitor.sh) to `$HOME/monitor.sh` and marks it executable (idempotent)
   - Usage after setup: `~/monitor.sh` (tmux split: top + watch sensors; requires lm-sensors, tmux, procps/procps-ng)

3b) Ensures Podman cleanup helper is available
   - Copies [linux_helpers/podman_cleanup.sh](linux_helpers/podman_cleanup.sh) to `$HOME/podman_cleanup.sh` and marks it executable (idempotent)
   - Always shows a Terraform-like preview before doing anything
   - Default interactive run asks for confirmation, then removes non-running containers and explicitly tries to remove all `<none>:<none>` images (images still used by a container are kept)
   - `-s` / `--select` opens a terminal-native `fzf` selector so you can mark any containers and any images to remove; Enter with nothing marked skips that step (containers or images), so you can remove only one kind; Esc cancels the whole run; the focused row is never picked implicitly
   - In `--select` mode, running containers and tagged images can also be chosen intentionally; images still used by a container you did not select are not force-removed
   - `fzf` is installed by the bootstrap/setup flow and used as the only selector backend
   - `DRY_RUN=1` shows the preview only and deletes nothing

3c) Ensures bash history cleanup helper is available
   - Copies [linux_helpers/clear_bash_history.sh](linux_helpers/clear_bash_history.sh) to `$HOME/clear_bash_history.sh` and marks it executable (idempotent)
   - No option prints help; `--orphans` removes `~/.bash_history-*.tmp`, `--file` empties `~/.bash_history`, `--session` clears the current shell's in-memory history (only when sourced: `. ~/clear_bash_history.sh --session`), `--all` does orphans + file (+ session when sourced)

3c2) Ensures the `init-repository` command is available
   - Copies [linux_helpers/init_repository.sh](linux_helpers/init_repository.sh) to `~/.local/bin/init-repository` and marks it executable (idempotent)
   - Run `init-repository` in a project folder: runs `git init` (branch `main`) if needed, adds a `mise.toml` pinning [tk](https://github.com/wedow/ticket), an `AGENTS.md` with the ticket/worktree workflow, and Git-ignored `.tickets/` and `.worktrees/`, then trusts the config and installs tk
   - A repository it creates gets an initial commit with only the setup files; in an existing one the changes are left for you to commit
   - Existing `mise.toml` and `AGENTS.md` are kept, and `.gitignore` is only appended to; a folder with its own mise config is not trusted automatically

3d) Configures a macOS-like close-window shortcut (best-effort)
   - Setup runs [linux_helpers/macos_quit_shortcut.sh](linux_helpers/macos_quit_shortcut.sh) directly; it is not copied to `$HOME`
   - On GNOME, it replaces the default `Alt+F4` close-window shortcut with `Super+Q`, the closest Linux equivalent to macOS `Command+Q`
   - Before assigning it, setup clears an existing single `Super+Q` shortcut so a competing GNOME component such as Ubuntu Dock cannot capture it
   - It closes the current app window; applications with multiple windows may remain open

3e) Pins installed apps to the GNOME dock (best-effort)
   - Setup runs [linux_helpers/pin_dock_apps.sh](linux_helpers/pin_dock_apps.sh) directly; it is not copied to `$HOME`
   - Appends installed apps from its `DOCK_APPS` list that are not pinned yet; existing pins and their order are kept
   - Re-running pins listed apps again if you unpinned them; edit `DOCK_APPS` to change the list

3f) Writes setup log to repository `logs/setup.log`
   - Overwrites on each run (single log file, no log-file buildup)
   - Terminal output is colorized for readability, while the saved log remains plain text with terminal control sequences stripped
   - Major setup and installer phases use boxed terminal headers again for easier scanning

### Per-app installers (idempotent)
You can run any installer directly if you don’t want the full bundle.

- Debian/Ubuntu (apt):
  - Brave: [linux_helpers/debian_apt/apps_installations/install_brave.sh](linux_helpers/debian_apt/apps_installations/install_brave.sh)
  - VS Code: [linux_helpers/debian_apt/apps_installations/install_code.sh](linux_helpers/debian_apt/apps_installations/install_code.sh)
  - VSCodium (official VSCodium APT repository; installs `codium`; an install without existing VSCodium settings also applies the settings, extensions and layout stored in `linux_helpers/codium/config`): [linux_helpers/debian_apt/apps_installations/install_codium.sh](linux_helpers/debian_apt/apps_installations/install_codium.sh)
  - KeePassXC (official `ppa:phoerious/keepassxc` on Ubuntu so `apt-get upgrade` tracks upstream releases; re-run to upgrade/migrate, swaps Ubuntu's `keepassxc-full` for the PPA build, `.kdbx` files and settings untouched; falls back to the distro package on Debian or when the PPA has no build for your release): [linux_helpers/debian_apt/apps_installations/install_keepassxc.sh](linux_helpers/debian_apt/apps_installations/install_keepassxc.sh)
  - LibreWolf (via `extrepo`; also removes Snap Firefox if present, but only when the `librewolf` command is available; snap keeps an automatic snapshot of its data, see `snap saved` / `snap restore <id>`): [linux_helpers/debian_apt/apps_installations/install_librewolf.sh](linux_helpers/debian_apt/apps_installations/install_librewolf.sh)
  - Signal Desktop (official Signal APT repository; skipped on non-amd64): [linux_helpers/debian_apt/apps_installations/install_signal.sh](linux_helpers/debian_apt/apps_installations/install_signal.sh)
  - Wireshark (apt package): [linux_helpers/debian_apt/apps_installations/install_wireshark.sh](linux_helpers/debian_apt/apps_installations/install_wireshark.sh)
  - Raspberry Pi Imager (apt package `rpi-imager`): [linux_helpers/debian_apt/apps_installations/install_rpi_imager.sh](linux_helpers/debian_apt/apps_installations/install_rpi_imager.sh)
  - Syncthing (official `apt.syncthing.net` `stable-v2` repo; backs up `~/.local/state/syncthing` to `~/syncthing-backup` before upgrading; enables the `syncthing@$USER` systemd service, web UI on `127.0.0.1:8384`): [linux_helpers/debian_apt/apps_installations/install_syncthing.sh](linux_helpers/debian_apt/apps_installations/install_syncthing.sh)
  - KVM + virt-manager (qemu, libvirt, OVMF; adds you to `libvirt`/`kvm` groups, re-login needed; `libvirt` membership is effectively passwordless root, undo with `sudo gpasswd -d $USER libvirt`; skipped when the CPU has no VT-x/AMD-V): [linux_helpers/debian_apt/apps_installations/install_virt_manager.sh](linux_helpers/debian_apt/apps_installations/install_virt_manager.sh)

### Manual usage
- Run only the toolchain bootstrap:
  - `bash linux_helpers/toolchains/bootstrap_toolchains.sh`
  - Add `-s` (or `--system`) to install apt prerequisites, mise, Podman, and terminal helpers
  - Without `--system`, mise must already be installed
  - Change global versions with `mise use --global node@<major>` (etc.); list them with `mise ls --global`
  - Optional: verify installed toolchains with `mise doctor`, `node -v`, `pnpm -v`, `bun --version`, `rustc --version`, `go version`, `uv --version`, `cs --version`, `scala --version`, `sqlite3def --version`, and `podman --version`
- Run only the Claude Code installer:
  - `bash linux_helpers/toolchains/install_claude.sh`
- Run the Podman cleanup helper directly:
  - `./linux_helpers/podman_cleanup.sh` to preview safe cleanup and confirm explicit removal of non-running containers plus `<none>:<none>` images
  - `./linux_helpers/podman_cleanup.sh -s` (or `--select`) to open an `fzf` selector and mark any containers/images to remove, including running containers or tagged images; images still used by unselected containers are kept
  - `DRY_RUN=1 ./linux_helpers/podman_cleanup.sh` to preview safe cleanup without deleting anything
  - `AUTO_APPROVE=1 ./linux_helpers/podman_cleanup.sh` for non-interactive safe cleanup
- Store/apply VSCodium configuration (Default profile settings, keybindings, snippets, extension list, UI layout) in `linux_helpers/codium/config`:
  - `./linux_helpers/codium/export_codium.sh` to export it into the repo; stops if likely secrets, emails or home paths are found (best-effort, review `git diff` before committing)
  - `./linux_helpers/codium/configure_codium.sh` to apply it (close VSCodium first so the layout is applied; changed files are backed up as `*.bak-<timestamp>`)
- Run system app installers through setup:
  - `./linux_helpers/setup.sh`
- Run an individual app installer directly:
  - `bash linux_helpers/debian_apt/apps_installations/install_code.sh`

Notes:
- All installers are intended to be idempotent and safe to re-run.
- The setup script also ensures the presence of an upgrade helper, a simple temperature monitor script, and a Podman cleanup helper in your home directory.
- The orchestrator enforces executability for install scripts and will stop if a script is not executable to avoid unintended permission changes.
