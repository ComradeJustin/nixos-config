#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

HOST="${1:-}"

# Auto-detect remote hosts from hosts/servers/ directory
REMOTE_HOSTS=""
if [[ -d "${FLAKE_DIR}/hosts/servers" ]]; then
    REMOTE_HOSTS=$(find "${FLAKE_DIR}/hosts/servers" -mindepth 1 -maxdepth 1 -type d ! -name '_template' -printf '%f ')
fi

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 <hostname>"
    echo ""
    echo "Local hosts:  nixpc, nixlaptop"
    echo "Remote hosts: ${REMOTE_HOSTS:-none}"
    exit 1
fi

if echo "$REMOTE_HOSTS" | grep -qw "$HOST"; then
    echo "Updating flake inputs and rebuilding ${HOST} remotely..."
    nix flake update "${FLAKE_DIR}"
    nixos-rebuild switch --flake "${FLAKE_DIR}#${HOST}" \
        --target-host "root@${HOST}" \
        --build-host "root@${HOST}" \
        --use-remote-sudo
else
    echo "Updating flake inputs and rebuilding ${HOST}..."
    nh os switch "${FLAKE_DIR}" -H "${HOST}" --update
fi
