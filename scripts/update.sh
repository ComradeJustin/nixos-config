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

echo "Updating flake inputs and rebuilding ${HOST}..."
nh os switch "${FLAKE_DIR}" -H "${HOST}" --update
