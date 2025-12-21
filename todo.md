# linux_utils Roadmap and TODO

Goal: make installs faster, safer, more maintainable, and support true user-only flows without requiring sudo for most desktop apps.

## Key changes (high impact)

- User-first installs and deterministic orchestration
  - Add env flags to the orchestrator [linux_utils/install_all.sh](linux_utils/install_all.sh:1):
    - PREFER_USER=1: prefer user-only flows (Flatpak --user, ~/.local/bin), warn/skip steps requiring sudo
    - DRY_RUN=1: print actions without executing
    - SUDO_VALIDATE=1: run sudo -v early to fail fast
    - INCLUDE_APPS/EXCLUDE_APPS: comma-separated filename globs to select apps
  - Sort tools/apps deterministically and apply include/exclude filters
- Deduplicate backend detection and helpers
  - Create shared lib [linux_utils/lib/common.sh](linux_utils/lib/common.sh:1) for:
    - [log()](linux_utils/install_all.sh:10), warn(), err(), [require_cmd()](linux_utils/install_all.sh:14)
    - detect_backend() used in [linux_utils/install_all.sh](linux_utils/install_all.sh:31), [linux_utils/setup.sh](linux_utils/setup.sh:20), [linux_utils/toolchains/bootstrap_toolchains.sh](linux_utils/toolchains/bootstrap_toolchains.sh:31)
    - retry_cmd() for transient network failures
- Debian Flatpak bootstrap
  - Add [linux_utils/debian_apt/apps_installations/install_flatpak.sh](linux_utils/debian_apt/apps_installations/install_flatpak.sh:1) mirroring Fedora’s user-remote setup in [linux_utils/fedora_dnf/apps_installations/install_flatpak.sh](linux_utils/fedora_dnf/apps_installations/install_flatpak.sh:23)
- Consolidate apt/dnf prerequisites
  - Move repeated apt-get update and small prereq installs into backend/tools_installations, e.g. wget/gpg/ca-certificates/unzip, instead of repeating inside each app script like:
    - [linux_utils/debian_apt/apps_installations/install_brave.sh](linux_utils/debian_apt/apps_installations/install_brave.sh:21)
    - [linux_utils/debian_apt/apps_installations/install_spotify.sh](linux_utils/debian_apt/apps_installations/install_spotify.sh:22)
- Single profile drop-in for PATH/env
  - Replace multi-shell appends in [ensure_path_entry()](linux_utils/toolchains/bootstrap_toolchains.sh:60) with a single drop-in: ~/.config/profile.d/myhelpers.sh and source once from ~/.profile (or shell RC)
- Go installer hardening
  - In [install_go()](linux_utils/toolchains/bootstrap_toolchains.sh:246):
    - Avoid global EXIT trap collisions (use subshell or local cleanup)
    - Skip if existing go version matches the target (compare go version output vs fetched latest)
- Non-interactive wallpaper
  - In [linux_utils/setup.sh](linux_utils/setup.sh:83), support:
    - WALLPAPER_SKIP=1 to bypass
    - WALLPAPER_MODE=zoom|centered|scaled|stretched|spanned to set non-interactively

## Security and correctness

- Keyrings and repos integrity
  - Where we fetch and place keyrings or repo files:
    - [install_brave.sh (APT)](linux_utils/debian_apt/apps_installations/install_brave.sh:53)
    - [install_code.sh (APT)](linux_utils/debian_apt/apps_installations/install_code.sh:46)
    - [install_firefox.sh (APT)](linux_utils/debian_apt/apps_installations/install_firefox.sh:55)
    - [install_brave.sh (DNF)](linux_utils/fedora_dnf/apps_installations/install_brave.sh:41)
  - Consider optional SHA256 validation for downloaded keyrings/repo files
  - For DNF repos ensure gpgcheck=1 (and repo_gpgcheck=1 where applicable) and gpgkey present
- Idempotent checks
  - Consistently use dpkg -s/rpm -q and command -v to short-circuit when already installed

## Reliability and ergonomics

- Retry wrapper
  - Implement retry_cmd() with backoff for apt update, dnf install, curl/wget fetches; put it in [linux_utils/lib/common.sh](linux_utils/lib/common.sh:1) and use across installers
- DRY_RUN and sudo pre-warm
  - DRY_RUN=1 prints the plan without executing in [linux_utils/install_all.sh](linux_utils/install_all.sh:59)
  - SUDO_VALIDATE=1 runs sudo -v early in [linux_utils/install_all.sh](linux_utils/install_all.sh:22)
- Logging controls
  - Add LOG_LEVEL=info|warn|error and QUIET=1 to suppress non-error logs
  - Centralize logging helpers in [linux_utils/lib/common.sh](linux_utils/lib/common.sh:1)

## Concrete task list

- [ ] Create shared lib [linux_utils/lib/common.sh](linux_utils/lib/common.sh:1) exposing:
  - [ ] log(), warn(), err()
  - [ ] require_cmd()
  - [ ] detect_backend()
  - [ ] retry_cmd()
- [ ] Refactor scripts to source common helpers:
  - [ ] Replace duplicate backend detection in [linux_utils/install_all.sh](linux_utils/install_all.sh:31)
  - [ ] Replace duplicate backend detection in [linux_utils/setup.sh](linux_utils/setup.sh:20)
  - [ ] Replace duplicate backend detection in [linux_utils/toolchains/bootstrap_toolchains.sh](linux_utils/toolchains/bootstrap_toolchains.sh:31)
- [ ] Enhance [linux_utils/install_all.sh](linux_utils/install_all.sh:22) with:
  - [ ] PREFER_USER, DRY_RUN, SUDO_VALIDATE, INCLUDE_APPS, EXCLUDE_APPS flags
  - [ ] Deterministic sort of tools/apps and filters
  - [ ] Relax hard sudo requirement if PREFER_USER=1 (warn and continue)
- [ ] Add Debian Flatpak bootstrap:
  - [ ] Implement [linux_utils/debian_apt/apps_installations/install_flatpak.sh](linux_utils/debian_apt/apps_installations/install_flatpak.sh:1)
  - [ ] When PREFER_USER=1 and sudo is unavailable, print actionable instruction to install system flatpak, but still set user remote if flatpak exists
- [ ] Consolidate apt/dnf prerequisites into backend/tools_installations and:
  - [ ] Remove redundant apt update and one-off pkg installs across Debian app installers (e.g., [install_brave.sh](linux_utils/debian_apt/apps_installations/install_brave.sh:21), [install_spotify.sh](linux_utils/debian_apt/apps_installations/install_spotify.sh:22))
  - [ ] Do similar consolidation on Fedora side as needed
- [ ] Replace multi-shell PATH edits with a single profile drop-in in [linux_utils/toolchains/bootstrap_toolchains.sh](linux_utils/toolchains/bootstrap_toolchains.sh:60)
  - [ ] Write ~/.config/profile.d/myhelpers.sh and ensure one line in ~/.profile sources it
- [ ] Harden Go installer [install_go()](linux_utils/toolchains/bootstrap_toolchains.sh:246)
  - [ ] Use subshell or local cleanup instead of a global EXIT trap
  - [ ] Skip if go version already matches the target version
- [ ] Make wallpaper non-interactive in [linux_utils/setup.sh](linux_utils/setup.sh:83)
  - [ ] Support WALLPAPER_SKIP=1 and WALLPAPER_MODE
- [ ] Security hardening for repos/keys
  - [ ] Optional SHA256 verification and strict gpgcheck settings (APT/DNF)
- [ ] Add retry wrappers to networked commands across scripts
- [ ] Add LOG_LEVEL/QUIET and unify logging
- [ ] Shellcheck and CI lint
  - [ ] Add a script to run shellcheck on all .sh files and fix surfaced issues
- [ ] Documentation
  - [ ] Update [README.md](README.md:1) with:
    - [ ] User-first mode (PREFER_USER)
    - [ ] Manual Flatpak usage (system vs user)
    - [ ] System-wide vs user-only install matrix
  - [ ] Add examples for INCLUDE_APPS/EXCLUDE_APPS and DRY_RUN usage

## Quick usage examples (after changes)

- Dry-run the app bundle for Debian:
  - DRY_RUN=1 BACKEND=debian_apt bash [linux_utils/install_all.sh](linux_utils/install_all.sh:1)
- Run only specific apps:
  - INCLUDE_APPS="install_code.sh,install_firefox.sh" bash [linux_utils/install_all.sh](linux_utils/install_all.sh:1)
- Exclude VirtualBox:
  - EXCLUDE_APPS="install_virtualbox.sh" bash [linux_utils/install_all.sh](linux_utils/install_all.sh:1)
- Prefer user installs:
  - PREFER_USER=1 bash [linux_utils/install_all.sh](linux_utils/install_all.sh:1)
- Pre-warm sudo:
  - SUDO_VALIDATE=1 bash [linux_utils/install_all.sh](linux_utils/install_all.sh:1)

## References to current code (for context)

- Orchestrator and helpers:
  - [linux_utils/install_all.sh](linux_utils/install_all.sh:10) (log), [linux_utils/install_all.sh](linux_utils/install_all.sh:14) (require_cmd), [linux_utils/install_all.sh](linux_utils/install_all.sh:31) (backend detection), [linux_utils/install_all.sh](linux_utils/install_all.sh:59) (tools loop), [linux_utils/install_all.sh](linux_utils/install_all.sh:106) (apps loop)
- Setup and wallpaper:
  - [linux_utils/setup.sh](linux_utils/setup.sh:20) (backend detection), [linux_utils/setup.sh](linux_utils/setup.sh:83) (wallpaper prompt)
- Fedora Flatpak bootstrap (reference behavior):
  - [linux_utils/fedora_dnf/apps_installations/install_flatpak.sh](linux_utils/fedora_dnf/apps_installations/install_flatpak.sh:23)
- Toolchains bootstrap:
  - [linux_utils/toolchains/bootstrap_toolchains.sh](linux_utils/toolchains/bootstrap_toolchains.sh:31) (backend detection), [linux_utils/toolchains/bootstrap_toolchains.sh](linux_utils/toolchains/bootstrap_toolchains.sh:60) (ensure_path_entry), [linux_utils/toolchains/bootstrap_toolchains.sh](linux_utils/toolchains/bootstrap_toolchains.sh:246) (install_go)