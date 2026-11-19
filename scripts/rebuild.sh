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

# Pull latest config if the working tree is clean. --ff-only never rewrites
# local commits: if the branches have diverged it fails and leaves the
# checkout as it was.
if git -C "$FLAKE_DIR" diff --quiet && git -C "$FLAKE_DIR" diff --cached --quiet; then
    git -C "$FLAKE_DIR" pull --ff-only --quiet \
        || echo "git pull failed (see the error above) — building current checkout"
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

    # Push the new system to nixpc's store so other machines can substitute it.
    # Harmonia signs paths as it serves them, so nothing is signed here.
    # /etc/nix/machines only exists on build clients, so nixpc skips this.
    if [[ -s /etc/nix/machines ]] && timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes justin@nixpc true 2>/dev/null; then
        SYSTEM_PATH="$(readlink -f /run/current-system)"
        echo "Pushing build to the nixpc cache..."
        nix copy --no-check-sigs --to ssh-ng://justin@nixpc "$SYSTEM_PATH" \
            || echo "Cache push failed (non-fatal)"
    fi
fi
