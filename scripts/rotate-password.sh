#!/usr/bin/env bash
# Rotate a user's login password and store the sha512-crypt hash in sops.
#
# The hash lives in secrets/secrets.yaml under "<user>_hashed_password" and is
# consumed by modules/core/sops.nix via hashedPasswordFile. Run this BEFORE
# rebuilding — a rebuild that references a missing secret will fail activation.
#
# Usage: bash scripts/rotate-password.sh [username]   (defaults to justin)
# Requires: sudo (to read this host's SSH key), sops, ssh-to-age, mkpasswd.
#
# NOTE: do NOT run a bare `sops secrets/secrets.yaml` — this repo has no
# personal age key in ~/.config/sops/age/keys.txt; the key is derived on the
# fly from this host's SSH host key, which is what this script does for you.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="${FLAKE_DIR}/secrets/secrets.yaml"
HOST_KEY="/etc/ssh/ssh_host_ed25519_key"
USER_NAME="${1:-justin}"
KEY="${USER_NAME}_hashed_password"

for bin in sops ssh-to-age mkpasswd; do
  command -v "$bin" >/dev/null || { echo "error: '$bin' not found in PATH" >&2; exit 1; }
done

# ── Derive this host's age identity from its SSH host key (needs sudo) ──
AGE_KEY="$(mktemp)"
chmod 600 "$AGE_KEY"
trap 'rm -f "$AGE_KEY"' EXIT

echo "Reading $HOST_KEY (sudo required)…"
sudo cat "$HOST_KEY" | ssh-to-age -private-key -o "$AGE_KEY"

if ! grep -q '^AGE-SECRET-KEY-' "$AGE_KEY"; then
  echo "error: failed to derive an age identity from $HOST_KEY." >&2
  echo "       (sudo cat may have produced no output, or this host's key" >&2
  echo "        is not one of the sops recipients in .sops.yaml)" >&2
  exit 1
fi
export SOPS_AGE_KEY_FILE="$AGE_KEY"

# ── Verify the key can actually decrypt before modifying anything ──
if ! sops decrypt "$SECRETS_FILE" >/dev/null 2>&1; then
  echo "error: derived key cannot decrypt $SECRETS_FILE." >&2
  echo "       This host ($(hostname)) may not be a recipient for this file." >&2
  exit 1
fi
echo "Key OK — can decrypt $SECRETS_FILE."

# ── Prompt for the new password ──
read -rsp "New password for ${USER_NAME}: " p1; echo
read -rsp "Confirm password: " p2; echo
[ -n "$p1" ] || { echo "error: empty password" >&2; exit 1; }
[ "$p1" = "$p2" ] || { echo "error: passwords do not match" >&2; exit 1; }

HASH="$(mkpasswd -m sha-512 -s <<<"$p1")"

# ── Write the secret (re-encrypts to every recipient already in the file) ──
sops set "$SECRETS_FILE" "[\"${KEY}\"]" "\"${HASH}\""

echo "OK: ${KEY} written to ${SECRETS_FILE}."
echo "Verify with:  SOPS_AGE_KEY_FILE=<derived> sops decrypt secrets/secrets.yaml | grep ${KEY}"
echo "Next: rebuild this host, then the new password is active on all hosts."
