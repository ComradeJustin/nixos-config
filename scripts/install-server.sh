#!/usr/bin/env bash
# Wipe a machine and install NixOS on it via nixos-anywhere + disko.
# The target must be booted into a NixOS live ISO with SSH reachable,
# and the host must have a disko disk-config (see hosts/servers/).
set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:-}"
TARGET="${2:-}"

if [[ -z "$HOST" || -z "$TARGET" ]]; then
    echo "Usage: $0 <host> <user@ip>"
    echo "Example: $0 home-core nixos@192.168.1.50"
    exit 1
fi

read -rp "This will ERASE ALL DATA on ${TARGET}. Continue? [y/N] " confirm
[[ "$confirm" == [yY] ]] || { echo "Aborted."; exit 1; }

nix run github:nix-community/nixos-anywhere -- \
    --flake "${FLAKE_DIR}#${HOST}" \
    --target-host "${TARGET}"

echo ""
echo "Install complete. Next steps:"
echo "  1. Join the tailnet:   ssh justin@<ip> 'sudo tailscale up'"
echo "  2. Future deploys:     scripts/rebuild.sh ${HOST} justin@<ip>"
echo "  3. To push builds to the cache, run fetch-cache-key on the new machine."
