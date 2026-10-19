#!/usr/bin/env bash
# Build and deploy a host of this flake.
#   rebuild.sh <host>            build + switch this machine
#   rebuild.sh <host> <user@ip>  build locally, deploy to a remote machine
# First deploy to a fresh machine: use root@<ip> so the store copy is trusted.
set -eo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:-}"
TARGET="${2:-}"

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 <host> [user@ip]"
    echo "Hosts: nixpc, nixlaptop"
    echo "With user@ip, builds locally and deploys to that machine."
    exit 1
fi

# Pull latest config if the working tree is clean
if git -C "$FLAKE_DIR" diff --quiet && git -C "$FLAKE_DIR" diff --cached --quiet; then
    git -C "$FLAKE_DIR" pull --rebase --quiet 2>/dev/null \
        || echo "git pull failed (offline?) — building current checkout"
else
    echo "Working tree is dirty — skipping git pull"
fi

# If the remote builder (nixpc) is reachable, cap local jobs so nix offloads to it.
# /etc/nix/machines only exists on build clients, so this is a no-op on nixpc itself.
EXTRA_ARGS=()
if [[ -s /etc/nix/machines ]] && timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes justin@nixpc true 2>/dev/null; then
    echo "Remote builder nixpc is online — capping local jobs at 4"
    EXTRA_ARGS=(-- --max-jobs 4)
fi

if [[ -n "$TARGET" ]]; then
    echo "Building ${HOST} and deploying to ${TARGET}..."
    nh os switch "$FLAKE_DIR" -H "$HOST" --ask --target-host "$TARGET" "${EXTRA_ARGS[@]}"
else
    echo "Building ${HOST} locally..."
    nh os switch "$FLAKE_DIR" -H "$HOST" --ask "${EXTRA_ARGS[@]}"

    # Push the new system to the harmonia cache so other machines can substitute it
    CACHE_KEY="/var/lib/harmonia-cache-key.pem"
    if [[ -f "$CACHE_KEY" ]] && timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes justin@nixpc true 2>/dev/null; then
        SYSTEM_PATH="$(readlink -f /run/current-system)"
        echo "Signing and pushing build to harmonia cache..."
        nix store sign --key-file "$CACHE_KEY" --recursive "$SYSTEM_PATH"
        nix copy --to ssh-ng://justin@nixpc "$SYSTEM_PATH" \
            || echo "Cache push failed (non-fatal)"
    fi
fi
