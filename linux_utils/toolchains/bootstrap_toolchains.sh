#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/toolchains/bootstrap_toolchains.sh
# Bootstrap developer toolchains for Debian/Ubuntu (apt)
#
# What it does:
# - Installs prerequisite build tools via apt (requires sudo)
# - Installs Node.js from official tarball, enables Corepack, activates pnpm
# - Respects NODE_VERSION (e.g., v22.11.0); otherwise uses latest LTS when possible
# - Adds PATH entries idempotently to common shell profiles
# - Installs uv (Astral) to ~/.local/bin
#
# Behavior:
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

# Detect apt environment only
BACKEND="debian_apt"
if have apt; then
  log "Detected Debian/Ubuntu (apt) environment."
else
  err "Unsupported Linux distribution: apt is required."
  exit 1
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
# 0) Prerequisites via apt
# -------------------------------------------------------------------
install_prereqs() {
  require_sudo
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -y
  sudo apt-get install -y \
    ca-certificates curl wget git unzip tar xz-utils gnupg \
    build-essential pkg-config make gcc
}

# Ensure git is installed and functional; install if missing.
verify_git() {
  if have git; then
    log "git present: $(git --version 2>/dev/null || true)"
  else
    require_sudo
    log "Installing git via apt..."
    sudo apt-get update -y || true
    sudo apt-get install -y git
    log "git installed: $(git --version 2>/dev/null || true)"
  fi
}

# -------------------------------------------------------------------
# 0.5) Terminal and container tools: tmux and podman
# -------------------------------------------------------------------

install_tmux() {
  require_sudo
  if have tmux; then
    log "tmux already installed: $(tmux -V || true)"
  else
    log "Installing tmux via apt..."
    sudo apt-get install -y tmux
  fi
}

install_top() {
  require_sudo
  if have top; then
    log "top already available: $(top -v 2>/dev/null | head -n1 || echo 'present')"
  else
    log "Installing procps (provides top, watch) via apt..."
    sudo apt-get install -y procps
  fi
}

install_podman() {
  require_sudo
  if have podman || dpkg -s podman >/dev/null 2>&1; then
    log "podman already installed: $(podman --version 2>/dev/null || echo 'present')"
    return
  fi

  apt_pkg_available() {
    local pkg="$1"
    local cand
    cand="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2}')"
    [[ -n "$cand" && "$cand" != "(none)" ]]
  }

  local pkgs=("podman")
  local extras=(uidmap slirp4netns fuse-overlayfs netavark aardvark-dns podman-docker)
  local x
  for x in "${extras[@]}"; do
    if apt_pkg_available "$x"; then
      pkgs+=("$x")
    fi
  done

  if ! apt_pkg_available netavark && apt_pkg_available containernetworking-plugins; then
    pkgs+=("containernetworking-plugins")
  fi

  log "Installing Podman and extras via apt: ${pkgs[*]}"
  sudo apt-get install -y "${pkgs[@]}"
}

# -------------------------------------------------------------------
# 1) Node.js + Corepack (pnpm)
# Installs Node.js from the official tarball; per-user install if sudo is unavailable, otherwise /usr/local. Corepack enables pnpm.
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
    # Attempt GPG verification of SHASUMS file if gpg is available
    if have gpg; then
      log "Attempting GPG verification of ${sumfile}..."
      local sumsig="SHASUMS256.txt.sig"
      curl -fsSL "https://nodejs.org/dist/${version}/${sumsig}" -o "$tmp/${sumsig}"

      # Use a temporary GNUPGHOME
      local gnupg_dir="$tmp/gnupg"
      mkdir -p "$gnupg_dir"
      chmod 700 "$gnupg_dir"

      # Node.js release keys (fingerprints)
      # Source: https://github.com/nodejs/node#release-keys
      local NODE_GPG_KEYS=(
        "94AE36675C464D64BAFA68DD7434390BDBE9B9C5"
        "1C050899334244A8AF75E53792EF661D867B9DFA"
        "71DCFD284A79C3B38668286BC97EC7A07EDE3FC1"
        "8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600"
        "C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8"
        "890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4"
        "A48C2BEE680E841632CD4E44F07496B3EB3C1762"
        "108F52B48DB57BB0CC439B2997B01419BD92F80A"
        "77984A986EBC2AA786BC0F66B01FBB92821C587A"
        "4ED778F539E3634C779C87C6D7062848A1AB005C"
      )

      local keyserver1="hkps://keys.openpgp.org"
      local keyserver2="hkps://keyserver.ubuntu.com"

      local imported=0
      for kid in "${NODE_GPG_KEYS[@]}"; do
        if gpg --homedir "$gnupg_dir" --batch --keyserver "$keyserver1" --recv-keys "$kid" >/dev/null 2>&1 || \
           gpg --homedir "$gnupg_dir" --batch --keyserver "$keyserver2" --recv-keys "$kid" >/dev/null 2>&1; then
          imported=1
        fi
      done

      if [[ "$imported" -eq 1 ]]; then
        if gpg --homedir "$gnupg_dir" --batch --verify "$tmp/${sumsig}" "$tmp/${sumfile}" >/dev/null 2>&1; then
          log "GPG verification of ${sumfile} succeeded."
        else
          warn "GPG verification of ${sumfile} failed; continuing with SHA256 check only."
        fi
      else
        warn "Unable to import Node.js release keys; continuing with SHA256 check only."
      fi
    else
      warn "gpg not available; skipping GPG verification of ${sumfile}."
    fi

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

  log "Installing uv (Astral) with staged download..."
  local UV_URL="${UV_INSTALL_URL:-https://astral.sh/uv/install.sh}"
  local UV_SHA256_EXPECTED="${UV_INSTALL_SHA256:-}"
  local tmp_uv
  tmp_uv="$(mktemp)"
  trap 'rm -f "$tmp_uv"' RETURN

  if ! curl -fsSL "$UV_URL" -o "$tmp_uv"; then
    err "Failed to download uv installer from $UV_URL"
    exit 1
  fi

  if [[ -n "$UV_SHA256_EXPECTED" ]]; then
    local UV_SHA256_ACTUAL
    UV_SHA256_ACTUAL="$(sha256sum "$tmp_uv" | awk '{print $1}')"
    if [[ "$UV_SHA256_ACTUAL" != "$UV_SHA256_EXPECTED" ]]; then
      err "uv installer SHA256 mismatch. Expected: $UV_SHA256_EXPECTED, Got: $UV_SHA256_ACTUAL"
      exit 1
    fi
    log "uv installer SHA256 verified."
  else
    warn "UV_INSTALL_SHA256 not set; proceeding without installer hash verification."
  fi

  sh "$tmp_uv"

  # Ensure ~/.local/bin on PATH
  ensure_path_entry 'export PATH="$HOME/.local/bin:$PATH"'
  export PATH="$HOME/.local/bin:$PATH"
  log "uv installed: $(uv --version || true)"
}

# -------------------------------------------------------------------
# 3) Shell prompt setup in ~/.bashrc
# -------------------------------------------------------------------
configure_bash_prompt() {
  local rc="$HOME/.bashrc"
  local BEGIN_MARK="# BEGIN MyHelpers prompt"
  local END_MARK="# END MyHelpers prompt"

  mkdir -p "$HOME"
  touch "$rc"

  if grep -qs "^${BEGIN_MARK}$" "$rc"; then
    log "Bash prompt block already present in $rc"
    return
  fi

  tee -a "$rc" >/dev/null <<'EOF'
# BEGIN MyHelpers prompt
# Parse Git branch nicely with a branch symbol
parse_git_branch() {
    git branch --no-color 2>/dev/null \
      | sed -n '/\* /s///p' \
      | sed -E 's/(.*)/ \1/'
}

# White for user@host, blue for dir, magenta for branch
if [[ $- == *i* ]]; then
  export PS1="\[\e[1;37m\]\u@\h \[\e[1;34m\]\W \[\e[1;35m\]\$(parse_git_branch)\[\e[0m\]$ "
fi
# END MyHelpers prompt
EOF
}

# -------------------------------------------------------------------
# Execute
# -------------------------------------------------------------------
log "Bootstrapping toolchains..."
install_prereqs
verify_git
install_tmux
install_top
install_podman
install_node_corepack
install_uv
configure_bash_prompt
log "Toolchain bootstrap completed."