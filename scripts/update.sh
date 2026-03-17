#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

HOST="${1:-}"

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 <hostname>"
    echo "Available hosts: nixpc, nixlaptop"
    exit 1
fi

echo "Updating flake inputs..."
nix flake update "${FLAKE_DIR}"

echo "Rebuilding ${HOST}..."
sudo nixos-rebuild switch --flake "${FLAKE_DIR}#${HOST}"
