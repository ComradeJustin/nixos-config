# NixOS Config

Multi-machine NixOS configuration with shared binary cache and distributed builds.

## Machines

| Host | Role | Location |
|------|------|----------|
| **nixpc** | Desktop, server (binary cache, AdGuard DNS, exit node, samba), remote builder | Always-on |
| **nixlaptop** | Desktop, build client | Local network |

## Scripts

```bash
scripts/rebuild.sh <host> [user@ip]   # Build and deploy a host
scripts/update.sh <host> [user@ip]    # Update flake inputs + rebuild
scripts/wake.sh                       # Wake nixpc via Wake-on-LAN
scripts/status.sh                     # Show network/infra status
scripts/install-server.sh <host> [user@ip]  # Fresh NixOS install via nixos-anywhere
scripts/bootstrap.sh <host> <user@ip>       # First deploy to an existing NixOS install
```

For local hosts (`nixpc`, `nixlaptop`), just pass the hostname. For remote/server hosts, the target defaults to `justin@<hostname>` via Tailscale DNS.

Shell aliases after rebuild: `rebuild`, `update`, `wake`, `infra-status`.

## Binary Cache (Harmonia)

nixpc runs [Harmonia](https://github.com/nix-community/harmonia) on port 5000, serving signed store paths to all machines.

### How it works

1. **nixpc** generates a signing keypair on first boot (`/var/lib/harmonia/cache-key.pem`)
2. Machines with `modules.nix-settings.harmonia = true` automatically:
   - Add `http://nixpc:5000` as a substituter
   - Fetch the signing key from nixpc via Tailscale SSH on first boot
   - Sign all local builds with the key (so they can be pushed to the cache)
3. After each rebuild, scripts auto-push the result to nixpc's store

### Adding a new machine to the cache

In the host's flake config:
```nix
modules.nix-settings.harmonia = true;
```

The signing key syncs automatically on first boot once the machine joins the Tailnet.

### Manual operations

```bash
# Check cache is working
curl http://nixpc:5000/nix-cache-info

# Push current system to cache
nix copy --to ssh-ng://root@nixpc $(readlink -f /run/current-system)

# Sign all paths on nixpc (after bulk upload)
ssh root@nixpc 'nix store sign --key-file /var/lib/harmonia/cache-key.pem --all'

# View the public key
ssh root@nixpc 'cat /var/lib/harmonia/cache-key.pub'
```

## Distributed Builds

nixpc acts as a remote builder. When scripts detect it's online, they limit local jobs to 4 so nix offloads work to nixpc.

Configure in flake:
```nix
modules.distributed-builds.enable = true;
modules.distributed-builds.role = "client";  # or "builder"
modules.distributed-builds.builders = [
  { hostName = "nixpc"; maxJobs = 8; speedFactor = 2; }
];
```
