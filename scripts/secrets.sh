#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="${1:-${FLAKE_DIR}/secrets/secrets.yaml}"

# Derive age key from host SSH key
AGE_KEY=$(mktemp)
trap 'rm -f "$AGE_KEY"' EXIT

sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key -o "$AGE_KEY"

SOPS_AGE_KEY_FILE="$AGE_KEY" sops "$SECRETS_FILE"
