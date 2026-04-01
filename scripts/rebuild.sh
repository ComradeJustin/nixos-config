#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

HOST="${1:-}"
TARGET="${2:-}"

# Auto-detect remote hosts from hosts/servers/ directory
REMOTE_HOSTS=""
if [[ -d "${FLAKE_DIR}/hosts/servers" ]]; then
    REMOTE_HOSTS=$(find "${FLAKE_DIR}/hosts/servers" -mindepth 1 -maxdepth 1 -type d ! -name '_template' -printf '%f ')
fi

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 <hostname> [user@ip]"
    echo ""
    echo "Local hosts:  nixpc, nixlaptop"
    echo "Remote hosts: ${REMOTE_HOSTS:-none}"
    echo ""
    echo "For remote hosts, optionally pass the target address:"
    echo "  $0 home-core justin@192.168.1.158"
    echo "If omitted, uses justin@<hostname> (works with Tailscale/DNS)"
    exit 1
fi

if echo "$REMOTE_HOSTS" | grep -qw "$HOST"; then
    REMOTE_TARGET="${TARGET:-justin@${HOST}}"
    echo "Building and deploying ${HOST} to ${REMOTE_TARGET}..."
    nixos-rebuild switch --flake "${FLAKE_DIR}#${HOST}" \
        --target-host "${REMOTE_TARGET}" \
        --build-host "${REMOTE_TARGET}" \
        --sudo
else
    nh os switch "${FLAKE_DIR}" -H "${HOST}" --ask
fi
