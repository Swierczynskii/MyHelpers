#!/usr/bin/env bash
set -euo pipefail
umask 022
# -----------------------------------------------------------------------------
# linux_utils/debian_apt/apps_installations/install_spotify.sh
# Install Spotify via official Spotify APT repository (keyrings + signed-by)
# Prerequisites: sudo, apt-get, curl or wget, gpg/dirmngr, ca-certificates, network access
# Usage: ./install_spotify.sh
# Non-interactive: export DEBIAN_FRONTEND=noninteractive
# -----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# Spotify installation via official Spotify APT repository (keyrings + signed-by)

# Ensure apt is available
if ! command -v apt >/dev/null 2>&1; then
  echo "apt not found. This script supports Debian/Ubuntu-based systems."
  exit 1
fi

# Skip if already installed
echo "[*] Checking if Spotify is already installed..."
if dpkg -s spotify-client >/dev/null 2>&1 || command -v spotify >/dev/null 2>&1; then
  echo " - spotify-client already installed. Skipping."
  exit 0
fi

echo "[*] Ensuring prerequisites..."
NEED_UPDATE=0
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo " - Installing wget (no curl/wget found)"
  sudo apt-get update
  sudo apt-get install -y wget
  NEED_UPDATE=1
fi
if ! command -v gpg >/dev/null 2>&1; then
  echo " - Installing gpg"
  [[ $NEED_UPDATE -eq 0 ]] && sudo apt-get update || true
  sudo apt-get install -y gpg
fi
if ! command -v dirmngr >/dev/null 2>&1; then
  echo " - Installing dirmngr (required for keyserver access)"
  [[ $NEED_UPDATE -eq 0 ]] && sudo apt-get update || true
  sudo apt-get install -y dirmngr
fi
if ! dpkg -s ca-certificates >/dev/null 2>&1; then
  echo " - Installing ca-certificates"
  [[ $NEED_UPDATE -eq 0 ]] && sudo apt-get update || true
  sudo apt-get install -y ca-certificates
fi

echo "[*] Preparing keyrings directory..."
sudo install -d -m 0755 /etc/apt/keyrings

ARCH=$(dpkg --print-architecture)
KEYRING="/etc/apt/keyrings/spotify-archive-keyring.gpg"
LIST="/etc/apt/sources.list.d/spotify.list"
KEYSERVER="hkps://keyserver.ubuntu.com"
# Known Spotify APT signing keys (long key IDs). Include rotated keys.
KEY_IDS=(C85668DF69375001 5384CE82BA52C83A 5E3C45D7B312C643)
# Official published key files (best-effort)
OFFICIAL_KEY_URLS=("https://download.spotify.com/debian/pubkey_5E3C45D7B312C643.gpg")

download_to_stdout() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  else
    wget -qO- "$url"
  fi
}

echo "[*] Installing Spotify signing keys (with fallback via keyserver)..."
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
COMBINED="$TMPDIR/spotify.gpg"
GNUPGHOME="$TMPDIR/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# Try official key URLs first (if reachable)
for url in "${OFFICIAL_KEY_URLS[@]}"; do
  if download_to_stdout "$url" > "$TMPDIR/official.gpg" 2>/dev/null; then
    if head -n1 "$TMPDIR/official.gpg" | grep -q "BEGIN PGP PUBLIC KEY BLOCK"; then
      gpg --dearmor < "$TMPDIR/official.gpg" >> "$COMBINED" 2>/dev/null || true
    else
      cat "$TMPDIR/official.gpg" >> "$COMBINED"
    fi
  fi
done

# Then fetch rotated keys from Ubuntu keyserver
for kid in "${KEY_IDS[@]}"; do
  if gpg --homedir "$GNUPGHOME" --batch --keyserver "$KEYSERVER" --recv-keys "$kid" >/dev/null 2>&1; then
    gpg --homedir "$GNUPGHOME" --batch --export "$kid" >> "$COMBINED" 2>/dev/null || true
  fi
done

if [[ -s "$COMBINED" ]]; then
  echo " - Writing consolidated keyring to $KEYRING"
  sudo install -m 0644 "$COMBINED" "$KEYRING"
else
  if [[ -f "$KEYRING" ]]; then
    echo " - No new keys fetched; using existing keyring: $KEYRING"
  else
    echo "ERROR: Failed to obtain Spotify signing keys."
    exit 1
  fi
fi

echo "[*] Adding Spotify APT repository..."
if [[ ! -f "$LIST" ]]; then
  echo "deb [arch=$ARCH signed-by=$KEYRING] https://repository.spotify.com stable non-free" | sudo tee "$LIST" >/dev/null
else
  echo " - Repository list already exists: $LIST"
fi

echo "[*] Updating package lists..."
sudo apt-get update

echo "[*] Installing spotify-client..."
sudo apt-get install -y spotify-client

echo "----------------------------------------------"
echo "Spotify installation complete."
echo "Launch: spotify"
echo "----------------------------------------------"