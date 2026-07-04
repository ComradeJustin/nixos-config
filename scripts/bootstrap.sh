#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

HOST="${1:-}"
TARGET="${2:-}"

if [[ -z "$HOST" || -z "$TARGET" ]]; then
    echo "Usage: $0 <hostname> <user@ip>"
    echo ""
    echo "Bootstraps a fresh NixOS install with your config."
    echo "The target must have NixOS installed and SSH accessible."
    echo ""
    echo "What it does:"
    echo "  1. Adds trusted-users on the target so it accepts store paths"
    echo "  2. Builds locally (using remote builders if available)"
    echo "  3. Deploys to the target"
    echo "  4. After first switch, Tailscale handles future deploys"
    echo ""
    echo "Examples:"
    echo "  $0 nixpc justin@192.168.1.158"
    echo "  $0 new-server justin@10.0.0.50"
    exit 1
fi

echo "=== Bootstrapping ${HOST} at ${TARGET} ==="
echo ""

# Step 1: Inject trusted-users on the target
echo "==> Step 1: Setting up trusted-users on target..."
REMOTE_USER="${TARGET%%@*}"
ssh -t "${TARGET}" "sudo mkdir -p /etc/nix/nix.conf.d && echo 'trusted-users = root ${REMOTE_USER}' | sudo tee /etc/nix/nix.conf.d/trusted.conf >/dev/null && sudo systemctl restart nix-daemon" || {
    echo "Warning: could not create nix.conf.d, trying alternative..."
    ssh -t "${TARGET}" "sudo sh -c 'systemctl stop nix-daemon; echo \"trusted-users = root ${REMOTE_USER}\" >> /etc/nix/nix.conf; systemctl start nix-daemon'"
}

echo "    Trusted-users configured."
echo ""

# Step 2: Build locally and deploy
echo "==> Step 2: Building locally and deploying to ${TARGET}..."

# Check for remote builders
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

MAX_JOBS_FLAG=""
if [[ "$BUILDERS_ONLINE" -gt 0 ]]; then
    echo "    Found ${BUILDERS_ONLINE} remote builder(s) online — limiting local jobs to 4"
    MAX_JOBS_FLAG="--max-jobs 4"
fi

nixos-rebuild switch --flake "${FLAKE_DIR}#${HOST}" \
    --target-host "${TARGET}" \
    --build-host localhost \
    --sudo --ask-sudo-password \
    ${MAX_JOBS_FLAG}

echo ""
echo "==> Step 3: Distributing harmonia cache key..."
REMOTE_HOST="${TARGET#*@}"
if ssh -o ConnectTimeout=3 root@nixpc "cat /var/lib/harmonia/cache-key.pem" 2>/dev/null | \
    ssh -t "${TARGET}" "sudo tee /var/lib/harmonia-cache-key.pem > /dev/null && sudo chmod 600 /var/lib/harmonia-cache-key.pem" 2>/dev/null; then
    echo "    Cache key installed."
else
    echo "    Warning: could not distribute cache key (nixpc unreachable?)"
fi

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "${HOST} is now running your config."
echo ""
echo "Next steps:"
echo "  - Log in to Tailscale on ${HOST}: ssh ${TARGET} 'sudo tailscale up'"
echo "  - Future deploys: ./scripts/rebuild.sh ${HOST}"
