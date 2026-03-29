#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

HOSTNAME="${1:-}"
TARGET="${2:-}"

if [[ -z "$HOSTNAME" || -z "$TARGET" ]]; then
    echo "Usage: $0 <hostname> <user@ip>"
    echo ""
    echo "Provisions a new NixOS server by:"
    echo "  1. Generating facter.json on the remote machine"
    echo "  2. Extracting filesystems from hardware-configuration.nix"
    echo "  3. Creating the host directory with networking.nix"
    echo ""
    echo "Example: $0 home-core root@192.168.1.100"
    exit 1
fi

HOST_DIR="${FLAKE_DIR}/hosts/servers/${HOSTNAME}"

if [[ -d "$HOST_DIR" ]] && [[ -f "$HOST_DIR/facter.json" ]]; then
    echo "Host directory ${HOST_DIR} already has facter.json."
    read -p "Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

mkdir -p "$HOST_DIR"

echo "==> Generating facter.json on ${TARGET}..."
ssh "$TARGET" 'nix run nixpkgs#nixos-facter -- -o /tmp/facter.json 2>/dev/null'
scp "$TARGET":/tmp/facter.json "$HOST_DIR/facter.json"
ssh "$TARGET" 'rm -f /tmp/facter.json'
echo "    Saved to ${HOST_DIR}/facter.json"

echo "==> Fetching hardware-configuration.nix from ${TARGET}..."
scp "$TARGET":/etc/nixos/hardware-configuration.nix "/tmp/hw-config-${HOSTNAME}.nix" 2>/dev/null || true

if [[ -f "/tmp/hw-config-${HOSTNAME}.nix" ]]; then
    echo "==> Extracting filesystems.nix..."
    # Extract fileSystems, swapDevices, and boot.initrd from hardware-configuration.nix
    # Keep everything except the kernel module and nixpkgs.hostPlatform lines that facter handles
    python3 -c "
import re, sys

with open('/tmp/hw-config-${HOSTNAME}.nix') as f:
    content = f.read()

# Lines to keep: fileSystems, swapDevices, boot.initrd, boot.loader, nixpkgs.hostPlatform
# Lines to drop: boot.kernelModules, boot.extraModulePackages, hardware.*, networking.*
# (facter handles kernel modules and hardware detection)

lines = content.split('\n')
output = []
skip_block = False
brace_depth = 0

for line in lines:
    stripped = line.strip()

    # Skip the function header and outer braces — we'll write our own
    if stripped.startswith('{') and ('config' in stripped or 'lib' in stripped or 'pkgs' in stripped or 'modulesPath' in stripped):
        continue
    if stripped == '{' and not output:
        continue

    # Skip lines facter handles
    if any(stripped.startswith(p) for p in [
        'boot.kernelModules',
        'boot.extraModulePackages',
        'hardware.cpu.',
        'hardware.enableRedistributable',
        'hardware.graphics',
        'networking.useDHCP',
    ]):
        continue

    # Skip comments about auto-generated
    if stripped.startswith('# Do not modify') or stripped.startswith('# Generated'):
        continue

    output.append(line)

# Clean up trailing braces and empty lines
while output and output[-1].strip() in ('', '}'):
    output.pop()

result = '\n'.join(output).strip()

print('{ ... }:')
print('{')
if result:
    print(result)
print('}')
" > "$HOST_DIR/filesystems.nix"
    rm -f "/tmp/hw-config-${HOSTNAME}.nix"
    echo "    Saved to ${HOST_DIR}/filesystems.nix"
else
    echo "    Could not fetch hardware-configuration.nix, creating stub..."
    cat > "$HOST_DIR/filesystems.nix" << 'NIXEOF'
# TODO: Run nixos-generate-config on the server and fill in these values
{ ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/XXXX";
  #   fsType = "ext4";
  # };

  # swapDevices = [ ];
}
NIXEOF
    echo "    Created stub at ${HOST_DIR}/filesystems.nix"
fi

# Create networking.nix if it doesn't exist
if [[ ! -f "$HOST_DIR/networking.nix" ]]; then
    cat > "$HOST_DIR/networking.nix" << NIXEOF
{ ... }:
{
  networking.hostName = "${HOSTNAME}";
}
NIXEOF
    echo "==> Created ${HOST_DIR}/networking.nix"
else
    echo "==> ${HOST_DIR}/networking.nix already exists, skipping"
fi

echo ""
echo "=== Provisioning complete ==="
echo ""
echo "Files created in ${HOST_DIR}:"
ls -1 "$HOST_DIR"
echo ""
echo "Next steps:"
echo "  1. Review ${HOST_DIR}/filesystems.nix — verify mounts and UUIDs"
echo "  2. Add host entry to flake.nix:"
echo ""
echo "        ${HOSTNAME} = mkHost {"
echo "          hostModules = ["
echo "            { hardware.facter.reportPath = ./hosts/servers/${HOSTNAME}/facter.json; }"
echo "            ./hosts/servers/${HOSTNAME}/filesystems.nix"
echo "            ./hosts/servers/${HOSTNAME}/networking.nix"
echo "            {"
echo "              modules.profiles.server.enable = true;"
echo "              modules.tailscale.enable = true;"
echo "              modules.distributed-builds.enable = true;"
echo "              modules.distributed-builds.role = \"builder\";"
echo "            }"
echo "          ];"
echo "        };"
echo ""
echo "  3. Deploy: ./scripts/rebuild.sh ${HOSTNAME}"
