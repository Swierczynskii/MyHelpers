#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/toolchains/bootstrap_toolchains.sh
# Bootstrap developer toolchains for Debian/Ubuntu (apt) and Fedora (dnf)
#
# What it does:
# - Installs prerequisite build tools via apt/dnf (requires sudo)
# - Installs Node.js from official tarball, enables Corepack, activates pnpm
# - Respects NODE_VERSION (e.g., v22.11.0); otherwise uses latest LTS when possible
# - Adds PATH entries idempotently to common shell profiles
# - Installs uv (Astral) to ~/.local/bin
#
# Behavior:
# - Backend auto-detected unless BACKEND env is set (debian_apt|fedora_dnf)
# - Idempotent and safe to re-run; will skip work when tools already available
# - Does not modify permissions outside intended install locations
#
# Notes:
# - Internet connection required
# - New shells may be required for PATH changes to take effect
# -----------------------------------------------------------------------------

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*" >&2
}

err() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

have() { command -v "$1" >/dev/null 2>&1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Detect backend if not provided via env
BACKEND="${BACKEND:-}"
if [[ -z "${BACKEND}" ]]; then
  if have apt; then
    BACKEND="debian_apt"
    log "Detected Debian/Ubuntu (apt) environment."
  elif have dnf; then
    BACKEND="fedora_dnf"
    log "Detected Fedora (dnf) environment."
  else
    err "Unsupported Linux distribution: neither apt nor dnf found."
    exit 1
  fi
else
  log "Using preselected backend: $BACKEND"
fi

# Utilities
append_unique_line() {
  # $1: file, $2: line to append if not present (exact match)
  local file="$1"
  local line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf "\n%s\n" "$line" >> "$file"
  fi
}

ensure_path_entry() {
  # $1: export line (e.g., export PATH="$HOME/.local/bin:$PATH")
  # Adds to common profiles idempotently
  local line="$1"
  local shell_profiles=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile")
  for f in "${shell_profiles[@]}"; do
    append_unique_line "$f" "$line"
  done
}

require_sudo() {
  if ! have sudo; then
    err "sudo is required for system-wide package installation."
    exit 1
  fi
}

# -------------------------------------------------------------------
# 0) Prerequisites via apt/dnf
# -------------------------------------------------------------------
install_prereqs() {
  case "$BACKEND" in
    debian_apt)
      require_sudo
      export DEBIAN_FRONTEND=noninteractive
      sudo apt-get update -y
      sudo apt-get install -y \
        ca-certificates curl wget git unzip tar xz-utils gnupg \
        build-essential pkg-config make gcc
      ;;
    fedora_dnf)
      require_sudo
      sudo dnf -y install \
        ca-certificates curl wget git unzip tar xz gnupg2 \
        @development-tools make gcc gcc-c++ pkgconf-pkg-config
      ;;
    *)
      err "Unknown backend: $BACKEND"
      exit 1
      ;;
  esac
}

# -------------------------------------------------------------------
# 1) Node.js + Corepack (pnpm)
# Prefer per-user install via nvm; fallback to system node if present.
# -------------------------------------------------------------------
install_node_corepack() {
  # Install latest LTS Node.js securely (official tarball + SHA256) and enable pnpm via Corepack.
  if have node; then
    log "Node.js already present: $(node -v || true)"
  else
    # Determine version: allow override via NODE_VERSION (e.g., v22.11.0)
    local version suffix tarball base url sumfile tmp
    if [[ -n "${NODE_VERSION:-}" ]]; then
      version="$NODE_VERSION"
    else
      # Query latest LTS from Node.js index; fallback to a pinned known LTS if unavailable
      if have curl; then
        version="$(curl -fsSL https://nodejs.org/dist/index.json | awk -F'"' '/"version":/ {v=$4} /"lts":\s*(true|".*")/ {print v; exit}')"
      fi
      version="${version:-v22.11.0}"
    fi

    # Detect arch suffix
    case "$(uname -m)" in
      x86_64) suffix="linux-x64" ;;
      aarch64|arm64) suffix="linux-arm64" ;;
      *) warn "Unsupported arch $(uname -m) for Node.js tarball"; return ;;
    esac

    base="node-${version}-${suffix}"
    tarball="${base}.tar.xz"
    url="https://nodejs.org/dist/${version}/${tarball}"
    sumfile="SHASUMS256.txt"

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    log "Downloading Node.js ${version} (${suffix}) and verifying checksum..."
    curl -fsSL "$url" -o "$tmp/${tarball}"
    curl -fsSL "https://nodejs.org/dist/${version}/${sumfile}" -o "$tmp/${sumfile}"
    (cd "$tmp" && grep " ${tarball}\$" "$sumfile" | sha256sum -c -) >/dev/null

    # Stage extraction
    tar -C "$tmp" -xf "$tmp/${tarball}"

    if have sudo; then
      require_sudo
      local root="/usr/local"
      local target="$root/${base}"
      log "Installing Node.js to ${target} and updating ${root}/node symlink..."
      sudo rm -rf "$target"
      sudo mv "$tmp/${base}" "$target"
      sudo ln -sfn "$target" "$root/node"
      ensure_path_entry 'export PATH="/usr/local/node/bin:$PATH"'
      export PATH="/usr/local/node/bin:$PATH"
    else
      local root="$HOME/.local"
      mkdir -p "$root"
      local target="$root/${base}"
      log "Installing Node.js to ${target} (per-user) and updating ${root}/node symlink..."
      rm -rf "$target"
      mv "$tmp/${base}" "$target"
      ln -sfn "$target" "$root/node"
      ensure_path_entry 'export PATH="$HOME/.local/node/bin:$PATH"'
      export PATH="$HOME/.local/node/bin:$PATH"
    fi
  fi

  # Enable Corepack and activate pnpm
  if have corepack; then
    log "Enabling Corepack and preparing pnpm..."
    corepack enable || warn "corepack enable failed; continuing."
    corepack prepare pnpm@latest --activate || warn "corepack prepare pnpm failed; continuing."
  else
    if have npx; then
      npx corepack enable || warn "npx corepack enable failed."
      npx corepack prepare pnpm@latest --activate || warn "npx corepack prepare pnpm failed."
    else
      warn "Corepack not found; ensure Node.js >=14.19 installed."
    fi
  fi

  if have pnpm; then
    log "pnpm detected: $(pnpm --version || true)"
  else
    warn "pnpm not on PATH; it will be available in new shells after Corepack initializes."
  fi
}

# -------------------------------------------------------------------
# 2) uv (Astral official installer)
# - Installs to ~/.local/bin by default
# -------------------------------------------------------------------
install_uv() {
  if have uv; then
    log "uv already installed: $(uv --version || true)"
    return
  fi
  log "Installing uv (Astral)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # Ensure ~/.local/bin on PATH
  ensure_path_entry 'export PATH="$HOME/.local/bin:$PATH"'
  export PATH="$HOME/.local/bin:$PATH"
  log "uv installed: $(uv --version || true)"
}

# -------------------------------------------------------------------
# Execute
# -------------------------------------------------------------------
log "Bootstrapping toolchains..."
install_prereqs
install_node_corepack
install_uv
log "Toolchain bootstrap completed."