# NixOS Config

Multi-machine NixOS configuration with shared binary cache and distributed builds.

## Machines

| Host | Role | Location |
|------|------|----------|
| **nixpc** | Desktop, server (binary cache, AdGuard DNS, exit node, samba), remote builder | Always-on |
| **nixlaptop** | Desktop, build client | Local network |

## Scripts

```bash
scripts/rebuild.sh <host> [user@ip]        # Build and deploy a host (local, or remote with user@ip)
scripts/update.sh <host> [user@ip]         # Update flake inputs, then rebuild
scripts/wake.sh <host>                     # Wake a machine via Wake-on-LAN
scripts/status.sh                          # Show network/infra status
scripts/install-server.sh <host> <user@ip> # Wipe + install NixOS via nixos-anywhere (live ISO)
```

Pass just the hostname to rebuild the machine you're on. Pass `user@ip` to build locally and deploy to another machine — for the first deploy to a fresh install, use `root@<ip>` so the store copy is trusted.

Shell aliases after rebuild: `rebuild`, `update`, `wake`, `infra-status`.

## Binary Cache (Harmonia)

nixpc runs [Harmonia](https://github.com/nix-community/harmonia) on port 5000, serving signed store paths to all machines.

### How it works

1. **nixpc** generates a signing keypair on first boot (`/var/lib/harmonia/cache-key.pem`)
2. Machines with `modules.nix-settings.harmonia = true` add `http://nixpc:5000` as a substituter
3. To push builds to the cache, a machine needs the signing key — run the `fetch-cache-key`
   shell function once to copy it from nixpc to `/var/lib/harmonia-cache-key.pem`
4. After each local rebuild, `rebuild.sh` signs the result and pushes it to nixpc's store

### Adding a new machine to the cache

In the host's flake config:
```nix
modules.nix-settings.harmonia = true;
```

Then run `fetch-cache-key` on the machine once it has joined the Tailnet, so its builds can be signed and pushed.

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
