# AGENTS.md

Additional instructions for agents working under `linux_utils/debian_apt/apps_installations/`.

## Scope
- This file applies only to files in this directory tree.
- It supplements the repository-root `AGENTS.md`.

## Purpose
- Scripts here install end-user applications for Debian/Ubuntu systems.
- They should be safe to re-run and should avoid reinstalling software that is already present.

## Script Style
- Keep each installer as a standalone Bash script.
- Prefer simple helper functions over heavy abstraction.
- Keep log output readable and action-oriented, using the existing `[*]`, `-`, and warning patterns already present in this folder.
- Preserve the current script naming pattern: `install_<app>.sh`.

## APT and Repository Handling
- Use `apt-get` for installs and updates inside scripts.
- When adding third-party repositories, prefer keyring-based `signed-by=` configuration.
- Clean up or replace duplicate repository entries when needed, but do not remove unrelated package sources.
- Only install prerequisite packages that are actually needed by the script.

## Installation Logic
- Detect existing installs early and skip when appropriate.
- If multiple install variants exist for the same app, detect what is already present before prompting.
- Interactive prompts should have a safe default; non-interactive execution should choose a deterministic fallback or skip rather than guess.
- Do not automatically remove a user’s existing installation unless the script already explicitly supports that behavior and the README documents it.

## User-Facing Output
- End scripts with a short success summary and basic launch/next-step hints when useful.
- If post-install manual setup is needed, print the exact follow-up command.

## Validation
- After editing a script in this folder, run `bash -n` on that script.
- If `shellcheck` is available, run it on that script as well.
