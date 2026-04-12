#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

HOST="${1:-}"
TARGET="${2:-}"

# Auto-pull latest config if working tree is clean
if git -C "${FLAKE_DIR}" diff --quiet && git -C "${FLAKE_DIR}" diff --cached --quiet; then
    echo "Pulling latest config..."
    git -C "${FLAKE_DIR}" pull --rebase --quiet 2>/dev/null || echo "Warning: git pull failed (offline or no remote?)"
else
    echo "Working tree is dirty — skipping git pull"
fi

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
    echo "  $0 nixpc root@nixpc"
    echo "If omitted for server hosts, uses justin@<hostname> (works with Tailscale/DNS)"
    echo "For local hosts, pass a target to deploy remotely instead of locally"
    exit 1
fi

if [[ -n "$TARGET" ]] || echo "$REMOTE_HOSTS" | grep -qw "$HOST"; then
    REMOTE_TARGET="${TARGET:-justin@${HOST}}"
    echo "Building locally and deploying ${HOST} to ${REMOTE_TARGET}..."
    nixos-rebuild switch --flake "${FLAKE_DIR}#${HOST}" \
        --target-host "${REMOTE_TARGET}" \
        --build-host localhost \
        --sudo --ask-sudo-password
else
    # Check if any remote builders are reachable
    BUILDERS_ONLINE=0
    if [[ -f /etc/nix/machines ]]; then
        while IFS=' ' read -r uri _rest; do
            [[ -z "$uri" ]] && continue
            builder_host="${uri#*@}"
            if sudo ssh -o ConnectTimeout=2 -o BatchMode=yes "root@${builder_host}" true 2>/dev/null; then
                BUILDERS_ONLINE=$((BUILDERS_ONLINE + 1))
            fi
        done < /etc/nix/machines
    fi

    if [[ "$BUILDERS_ONLINE" -gt 0 ]]; then
        echo "Found ${BUILDERS_ONLINE} remote builder(s) online — limiting local jobs to 4"
        nh os switch "${FLAKE_DIR}" -H "${HOST}" --ask -- --max-jobs 4
    else
        echo "No remote builders reachable — using all local cores"
        nh os switch "${FLAKE_DIR}" -H "${HOST}" --ask
    fi
fi
