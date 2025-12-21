#!/usr/bin/env bash
set -euo pipefail

# Bootstrap developer toolchains on Debian/Ubuntu (apt) and Fedora (dnf)
# Installs:
# - Node.js (prefers nvm per-user) + Corepack (pnpm via corepack prepare)
# - Bun (official script)
# - uv (Astral official installer)
# - Rust (rustup)
# - Go (official tarball to /usr/local/go with sudo, or ~/.local/go fallback)
#
# Idempotent and backend-aware. Safe to re-run.

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
  # If any usable node already present, skip nvm and just enable corepack
  if have node; then
    log "Node.js already present: $(node -v || true)"
  else
    # Install nvm per official installer
    local NVM_DIR="$HOME/.nvm"
    if [[ ! -d "$NVM_DIR" ]]; then
      log "Installing nvm (per-user)..."
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    else
      log "nvm already installed at $NVM_DIR"
    fi

    # Load nvm into current shell
    # shellcheck disable=SC1090
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    if ! have node; then
      log "Installing latest LTS Node.js via nvm..."
      nvm install --lts
      nvm alias default 'lts/*'
      nvm use default
    fi

    # Add NVM sourcing lines to profiles
    ensure_path_entry 'export NVM_DIR="$HOME/.nvm"'
    ensure_path_entry '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm'
    ensure_path_entry '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" # This loads nvm bash_completion'
  fi

  # Corepack: available in Node >= 14.19 < 25 by default
  if have corepack; then
    log "Enabling Corepack..."
    corepack enable || warn "corepack enable failed; continuing."
    # Activate latest pnpm shims globally
    log "Activating latest pnpm via Corepack..."
    corepack prepare pnpm@latest --activate || warn "corepack prepare pnpm failed; continuing."
  else
    # corepack should be available via node binary path; try npx corepack enable as a fallback
    warn "corepack not found in PATH; attempting 'node --version' and 'npx corepack enable' workaround..."
    if have npx; then
      npx corepack enable || warn "npx corepack enable failed."
      npx corepack prepare pnpm@latest --activate || warn "npx corepack prepare pnpm failed."
    else
      warn "npm/npx not found; ensure Node.js installed correctly."
    fi
  fi

  # Verify pnpm resolves via Corepack shim
  if ! have pnpm; then
    warn "pnpm not on PATH yet. After opening a new shell, pnpm should be available via Corepack."
  else
    log "pnpm detected: $(pnpm --version || true)"
  fi
}

# -------------------------------------------------------------------
# 2) Bun (official script) - requires unzip
# -------------------------------------------------------------------
install_bun() {
  # Make sure we detect existing per-user installs even if PATH isn't set
  local bun_user_bin="$HOME/.bun/bin/bun"

  if have bun; then
    # Ensure PATH is persisted and available in current shell
    ensure_path_entry 'export PATH="$HOME/.bun/bin:$PATH"'
    export PATH="$HOME/.bun/bin:$PATH"
    log "bun already installed: $(bun --version || true)"
    return
  elif [[ -x "$bun_user_bin" ]]; then
    # Bun is installed but not on PATH; fix PATH and skip reinstall
    ensure_path_entry 'export PATH="$HOME/.bun/bin:$PATH"'
    export PATH="$HOME/.bun/bin:$PATH"
    log "bun detected at $bun_user_bin; version: $("$bun_user_bin" --version || true)"
    return
  fi

  if ! have unzip; then
    log "Installing unzip prerequisite for Bun..."
    install_prereqs # ensures unzip via backend path
  fi

  log "Installing Bun..."
  # Official installer
  curl -fsSL https://bun.sh/install | bash
  # Add .bun/bin to PATH
  ensure_path_entry 'export PATH="$HOME/.bun/bin:$PATH"'
  # Attempt to load in current shell if available
  export PATH="$HOME/.bun/bin:$PATH"
  log "bun installed: $(bun --version || true)"
}

# -------------------------------------------------------------------
# 3) uv (Astral official installer)
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
# 4) Rust (rustup) + cargo
# -------------------------------------------------------------------
install_rust() {
  if have cargo; then
    log "Rust/cargo already installed: cargo $(cargo --version || true)"
    return
  fi
  log "Installing Rust via rustup (non-interactive)..."
  curl -fsSL https://sh.rustup.rs | sh -s -- -y
  # Source cargo env for current shell
  # shellcheck disable=SC1091
  [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  ensure_path_entry 'source "$HOME/.cargo/env"'
  log "Rust installed: $(rustc --version || true); cargo: $(cargo --version || true)"
}

# -------------------------------------------------------------------
# 5) Go (official tarball)
# - To /usr/local/go if sudo available, else per-user at ~/.local/go
# -------------------------------------------------------------------
detect_go_archive_suffix() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) echo "linux-amd64" ;;
    aarch64) echo "linux-arm64" ;;
    arm64) echo "linux-arm64" ;;
    *) echo "" ;;
  esac
}

latest_go_version() {
  # Try to fetch the latest release tag text (e.g., go1.25.4); fall back to a pinned known version
  if have curl; then
    if ver="$(curl -fsSL https://go.dev/VERSION?m=text 2>/dev/null | head -n1)"; then
      echo "$ver"
      return
    fi
  fi
  echo "go1.25.4"
}

install_go() {
  if have go; then
    log "Go already installed: $(go version || true)"
    return
  fi

  local suffix
  suffix="$(detect_go_archive_suffix)"
  if [[ -z "$suffix" ]]; then
    warn "Unsupported architecture '$(uname -m)' for auto Go install; skipping."
    return
  fi

  local version
  version="$(latest_go_version)"
  local tarball="${version}.${suffix}.tar.gz"
  local url="https://go.dev/dl/${tarball}"

  log "Preparing to install Go ${version} for ${suffix}..."

  # Prefer system-wide install to /usr/local/go if possible
  if have sudo; then
    log "Downloading ${url}..."
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL "$url" -o "$tmp/${tarball}"
    log "Installing Go to /usr/local/go (requires sudo)..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$tmp/${tarball}"
    ensure_path_entry 'export PATH="/usr/local/go/bin:$PATH"'
    export PATH="/usr/local/go/bin:$PATH"
    # GOPATH suggestion
    ensure_path_entry 'export GOPATH="$HOME/go"'
    ensure_path_entry 'export PATH="$GOPATH/bin:$PATH"'
    log "Go installed: $(go version || true)"
  else
    # Per-user fallback
    local target="$HOME/.local/go"
    mkdir -p "$HOME/.local"
    log "Downloading ${url}..."
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL "$url" -o "$tmp/${tarball}"
    log "Installing Go to $target (per-user)..."
    rm -rf "$target"
    tar -C "$HOME/.local" -xzf "$tmp/${tarball}"
    ensure_path_entry 'export PATH="$HOME/.local/go/bin:$PATH"'
    ensure_path_entry 'export GOPATH="$HOME/go"'
    ensure_path_entry 'export PATH="$GOPATH/bin:$PATH"'
    export PATH="$HOME/.local/go/bin:$PATH"
    log "Go installed: $(go version || true)"
  fi
}

# -------------------------------------------------------------------
# Execute
# -------------------------------------------------------------------
log "Bootstrapping toolchains..."
install_prereqs
install_node_corepack
install_bun
install_uv
install_rust
install_go
log "Toolchain bootstrap completed."