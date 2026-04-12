#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

HOST="${1:-}"
TARGET="${2:-}"

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 <hostname> [user@ip]"
    echo ""
    echo "Installs NixOS on a remote machine using nixos-anywhere + disko."
    echo "The target must be booted into a NixOS live ISO with SSH enabled."
    echo ""
    echo "Examples:"
    echo "  $0 home-core nixos@192.168.1.158    # live ISO default user"
    echo "  $0 home-core root@192.168.1.158     # if root SSH is enabled"
    echo ""
    echo "After install, the script will:"
    echo "  1. Run nixos-anywhere to partition disks and install"
    echo "  2. Wait for the machine to reboot"
    echo "  3. Generate nixos-facter hardware report"
    echo "  4. Rebuild with the final configuration"
    exit 1
fi

# Default target for live ISO is usually nixos@ or root@
REMOTE_TARGET="${TARGET:-nixos@${HOST}}"

# Extract just the IP/hostname from user@host
REMOTE_HOST="${REMOTE_TARGET#*@}"

echo "=== Step 1: Install NixOS on ${HOST} via nixos-anywhere ==="
echo "Target: ${REMOTE_TARGET} (must be booted into NixOS live ISO)"
echo ""
read -rp "This will ERASE ALL DATA on the target disk. Continue? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "Aborted."
    exit 1
fi

nix run github:nix-community/nixos-anywhere -- \
    --flake "${FLAKE_DIR}#${HOST}" \
    --target-host "${REMOTE_TARGET}" \
    --phases "kexec,disko,install"

echo ""
echo "=== Step 2: Rebooting ${REMOTE_HOST} ==="
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${REMOTE_TARGET}" "sudo reboot" 2>/dev/null || true
echo "Reboot triggered. Waiting for SSH to come back up..."

# Remove old host key since the install generates new ones
ssh-keygen -R "${REMOTE_HOST}" 2>/dev/null || true

# Wait for the machine to go down
sleep 15

# Wait for SSH to come back (now as justin, the configured user)
DEPLOY_TARGET="justin@${REMOTE_HOST}"
for i in $(seq 1 60); do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${DEPLOY_TARGET}" true 2>/dev/null; then
        echo "SSH is back up!"
        break
    fi
    if [[ $i -eq 60 ]]; then
        echo "Timed out waiting for SSH. The machine may still be booting."
        echo "Once it's up, run these commands manually:"
        echo "  ssh ${DEPLOY_TARGET} 'nix run nixpkgs#facter -- --json > /tmp/facter.json'"
        echo "  scp ${DEPLOY_TARGET}:/tmp/facter.json ${FLAKE_DIR}/hosts/servers/${HOST}/facter.json"
        echo "  scripts/rebuild.sh ${HOST} ${DEPLOY_TARGET}"
        exit 1
    fi
    echo "  Attempt ${i}/60 — retrying in 5s..."
    sleep 5
done

echo ""
echo "=== Step 3: Generating nixos-facter hardware report ==="

ssh -t "${DEPLOY_TARGET}" \
    "sudo nix run --extra-experimental-features 'nix-command flakes' nixpkgs#facter -- --json | sudo tee /tmp/facter.json > /dev/null"

scp "${DEPLOY_TARGET}:/tmp/facter.json" "${FLAKE_DIR}/hosts/servers/${HOST}/facter.json"
echo "Saved facter.json to hosts/servers/${HOST}/facter.json"

echo ""
echo "=== Step 4: Final rebuild ==="
echo "Rebuilding ${HOST} with hardware-specific facter data..."

"${SCRIPT_DIR}/rebuild.sh" "${HOST}" "${DEPLOY_TARGET}"

echo ""
echo "=== Step 5: Distributing harmonia cache key ==="
if ssh -o ConnectTimeout=3 root@home-core "cat /var/lib/harmonia/cache-key.pem" 2>/dev/null | \
    ssh "root@${REMOTE_HOST}" "tee /var/lib/harmonia-cache-key.pem > /dev/null && chmod 600 /var/lib/harmonia-cache-key.pem" 2>/dev/null; then
    echo "Cache key installed on ${HOST}."
else
    echo "Warning: could not distribute cache key (home-core unreachable?)"
fi

echo ""
echo "=== Done! ==="
echo "${HOST} is installed and configured at ${REMOTE_HOST}"
