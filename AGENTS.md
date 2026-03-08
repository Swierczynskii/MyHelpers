# AGENTS.md

Instructions for agents working in this repository.

## Scope
- This file applies to the entire repository unless a deeper `AGENTS.md` overrides it.

## Repository Layout
- `linux_utils/` contains Linux shell helpers and setup flows.
- `linux_utils/debian_apt/apps_installations/` contains Debian/Ubuntu app installer scripts.
- `linux_utils/toolchains/` contains developer toolchain bootstrap scripts.
- `win_utils/` contains Windows batch/PowerShell helpers.
- `README.md` documents end-user behavior and should stay aligned with user-facing changes.

## Shell Script Conventions
- Use `#!/usr/bin/env bash` with `set -euo pipefail` and `umask 022` for Bash scripts unless there is a strong repo-local reason not to.
- Prefer small shell functions for repeated logic.
- Keep scripts idempotent when practical.
- Prefer `apt-get` over `apt` for non-interactive installs inside scripts.
- For non-interactive package installs, set `DEBIAN_FRONTEND=noninteractive` when appropriate.
- Preserve the repo's current style: concise status output, minimal abstraction, and straightforward control flow.

## Installer Behavior
- Installers should detect existing installations and skip work when possible.
- If behavior is interactive, keep a safe default and make non-interactive behavior deterministic.
- Do not silently broaden the scope of destructive actions.
- When copying helpers into `$HOME` from `linux_utils/setup.sh`, follow the existing pattern used for `monitor.sh`, `upgrade.sh`, and `podman_cleanup.sh`.
- Do not change executable permissions broadly; preserve existing repo behavior unless the user explicitly requests a permission change.

## Documentation
- Update `README.md` whenever a user-facing script changes behavior, flags, prompts, install flow, or setup integration.
- Keep documentation concise and practical, matching the current README tone.

## Validation
- After editing Bash scripts, run `bash -n` on the changed files.
- If `shellcheck` is available, run it on changed shell scripts.
- Prefer targeted validation over broad unrelated test runs.

## Change Scope
- Keep changes focused on the user’s request.
- Avoid unrelated refactors.
- Do not add new dependencies or frameworks unless clearly necessary.
