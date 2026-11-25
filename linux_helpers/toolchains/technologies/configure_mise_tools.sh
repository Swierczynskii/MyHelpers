#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install the global developer toolchains with mise (verified downloads, one config file).
# Global defaults live in ~/.config/mise/config.toml; a repo's own mise.toml overrides them.
# Python versions are managed by uv, so Python is intentionally not listed here.
# Usable standalone (bash technologies/configure_mise_tools.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Java is needed at runtime by the Coursier launchers for scala, sbt, and metals.
# node@lts follows each new LTS line automatically (mise upgrade moves to it).
MISE_GLOBAL_TOOLS=(node@lts pnpm@latest go@latest rust@stable bun@latest uv@latest java@temurin-21 sqlite3def@latest coursier@latest)

# Run mise against the global config only: a project config in the current directory or a
# MISE_<TOOL>_VERSION variable would hide or replace global tool requests.
mise_global() (
  local var
  for var in "${!MISE_@}"; do
    if [[ "$var" == MISE_*_VERSION ]]; then
      unset "$var"
    fi
  done
  cd /
  mise "$@"
)

# Print the tool names declared in the user's global config, one per line (nothing when it is empty or missing).
# 'config ls' is used because 'mise ls' omits disabled and other-OS tools; mise normalizes aliases such as nodejs.
mise_global_tool_names() {
  mise_global config ls --json | awk '
    /"path":/ { system_config = ($0 ~ /"\/etc\//); next }
    /^[[:space:]]+"[^"]+",?$/ && !system_config { gsub(/[[:space:]",]/, ""); print }'
}

# True when $2 (declared names) has $1 under its short name or one of its backends (e.g. aqua:pnpm/pnpm).
mise_tool_declared() {
  local tool="$1" declared="$2" backends name
  backends="$(mise_global registry "$tool" 2>/dev/null || true)"
  for name in "$tool" $backends; do
    if grep -Fqx -- "$name" <<< "$declared"; then
      return 0
    fi
  done
  return 1
}

# The scala launcher resolves the java shim symlink to /usr/bin/mise and breaks, so login shells also need
# JAVA_HOME. It is set only when unset: ~/.profile may source ~/.bashrc first, where 'mise activate' has
# already set it for the current project. An existing JAVA_HOME line is never changed.
configure_java_home() {
  local java_bin version java_line profile
  # 'which' gives the active Java even when several are configured.
  java_bin="$(mise_global which java 2>/dev/null)" || java_bin=''
  version="${java_bin#"$HOME/.local/share/mise/installs/java/"}"
  version="${version%/bin/java}"
  if [[ ! "$version" =~ ^[A-Za-z0-9._+-]+$ || ! -x "$HOME/.local/share/mise/installs/java/$version/bin/java" ]]; then
    warn "No mise installation found for the global Java (${version:-none}); JAVA_HOME not configured."
    return
  fi

  java_line="[ -n \"\${JAVA_HOME:-}\" ] || export JAVA_HOME=\"\$HOME/.local/share/mise/installs/java/$version\""
  for profile in "$HOME/.profile" "$HOME/.bash_profile"; do
    if [[ "$profile" == "$HOME/.profile" || -f "$profile" ]]; then
      if grep -Fqsx -- "$java_line" "$profile"; then
        continue
      elif grep -Eqs '^([^#]*[[:space:]])?JAVA_HOME=' "$profile"; then
        log "Keeping the existing JAVA_HOME in $profile; for the global mise Java use: $java_line"
      else
        append_unique_line "$profile" "$java_line"
      fi
    fi
  done
}

configure_mise_tools() {
  if ! have mise; then
    err "mise not found. Run bootstrap_toolchains.sh --system (installs mise from its signed APT repo) and rerun."
    exit 1
  fi

  # Interactive shells use 'mise activate' (install_mise.sh); login files get the shims so
  # non-interactive shells, scripts, and GUI apps (e.g. editors started from the launcher) see the tools too.
  local shims_line="export PATH=\"\$HOME/.local/share/mise/shims:\$PATH\""
  local profile
  for profile in "$HOME/.profile" "$HOME/.bash_profile"; do
    if [[ "$profile" == "$HOME/.profile" || -f "$profile" ]]; then
      append_unique_line "$profile" "$shims_line"
    fi
  done
  export PATH="$HOME/.local/share/mise/shims:$PATH"

  # Add only absent tools; version requests the user already has are never replaced.
  local declared tool
  local missing=()
  if ! declared="$(mise_global_tool_names)"; then
    err "Could not read the global mise config; not changing it."
    exit 1
  fi
  for tool in "${MISE_GLOBAL_TOOLS[@]}"; do
    if ! mise_tool_declared "${tool%@*}" "$declared"; then
      missing+=("$tool")
    fi
  done

  if (( ${#missing[@]} )); then
    log "Adding global tools with mise: ${missing[*]}"
    mise_global use --global "${missing[@]}"
  else
    log "All default tools are already in the global mise config."
  fi
  log "Installing any configured global tools that are missing..."
  mise_global install
  hash -r || true
  configure_java_home

  log "Global mise tools:"
  mise_global ls --global --current || true
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  configure_mise_tools
fi
