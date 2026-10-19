#!/usr/bin/env bash
# Update all flake inputs, then build and deploy via rebuild.sh.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nix flake update --flake "$(dirname "$SCRIPT_DIR")"
exec "$SCRIPT_DIR/rebuild.sh" "$@"
