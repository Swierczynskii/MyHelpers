#!/usr/bin/env bash
set -euo pipefail
umask 022
# Install Node.js (official tarball, SHA256/GPG verified) and enable pnpm via Corepack.
# Usable standalone (bash technologies/install_node.sh) or sourced by bootstrap_toolchains.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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

    if [[ "${SYSTEM_NODE:-0}" == "1" ]]; then
      if (( ! SYSTEM_MODE )); then
        err "SYSTEM_NODE=1 requires --system because it writes Node.js under /usr/local."
        exit 1
      fi
      require_sudo
      local root="/usr/local"
      local target="$root/${base}"
      log "Installing Node.js to ${target} and updating ${root}/node symlink..."
      sudo rm -rf "$target"
      sudo mv "$tmp/${base}" "$target"
      sudo ln -sfn "$target" "$root/node"
      ensure_path_entry "export PATH=\"/usr/local/node/bin:\$PATH\""
      export PATH="/usr/local/node/bin:$PATH"
    else
      local root="$HOME/.local"
      mkdir -p "$root"
      local target="$root/${base}"
      log "Installing Node.js to ${target} (per-user) and updating ${root}/node symlink..."
      rm -rf "$target"
      mv "$tmp/${base}" "$target"
      ln -sfn "$target" "$root/node"
      ensure_path_entry "export PATH=\"\$HOME/.local/node/bin:\$PATH\""
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  guard_against_sudo
  install_node_corepack
fi
