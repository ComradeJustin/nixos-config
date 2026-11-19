# NixOS Config

Multi-machine NixOS configuration with shared binary cache and distributed builds.

## Machines

| Host | Role | Location |
|------|------|----------|
| **nixpc** | Headless server (binary cache, AdGuard DNS, exit node, samba, website), remote builder | Always-on |
| **nixlaptop** | Desktop, build client | Local network |

## Layout

```
flake.nix          inputs and the two hosts
hosts/<name>/      default.nix imports every module that machine uses
modules/base.nix   what every machine gets (Nix settings, user, SSH, CLI tools)
modules/desktop/   the graphical desktop (niri, shell widgets, audio, theme)
modules/server/    services nixpc runs (AdGuard, Harmonia, Samba, website)
home/base.nix      Home Manager for every machine (shell, git, prompt)
home/desktop.nix   Home Manager for desktop machines (GUI apps and their config)
```

Importing a module turns it on; there are no enable flags. To see what a machine runs, read its `hosts/<name>/default.nix`.

Where to add a program:

- every machine: `environment.systemPackages` in `modules/base.nix`
- a GUI app: `home.packages` in `home/desktop.nix`
- one machine only: that host's `default.nix`

## Scripts

```bash
scripts/rebuild.sh <host> [user@ip]        # Build and deploy a host (local, or remote with user@ip)
scripts/update.sh <host> [user@ip]         # Update flake inputs, then rebuild
scripts/wake.sh <host>                     # Wake a machine via Wake-on-LAN
scripts/status.sh                          # Show network/infra status
```

Pass just the hostname to rebuild the machine you're on. Pass `user@ip` to build locally and deploy to another machine — for the first deploy to a fresh install, use `root@<ip>` so the store copy is trusted.

Shell aliases after rebuild: `rebuild`, `update`, `wake`, `infra-status`.

## Binary Cache (Harmonia)

nixpc runs [Harmonia](https://github.com/nix-community/harmonia) on port 5000, serving signed store paths to all machines.

### How it works

1. **nixpc** generates a signing keypair on first boot (`/var/lib/harmonia/cache-key.pem`)
2. Client machines add `http://nixpc:5000` as a substituter (see `hosts/nixlaptop/default.nix`)
3. To push builds to the cache, a machine needs the signing key — run the `fetch-cache-key`
   shell function once to copy it from nixpc to `/var/lib/harmonia-cache-key.pem`
4. After each local rebuild, `rebuild.sh` signs the result and pushes it to nixpc's store

### Adding a new machine to the cache

Copy the `nix.settings.substituters` and `trusted-public-keys` lines from `hosts/nixlaptop/default.nix` into the new host's `default.nix`.

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

The client side is the `nix.buildMachines` block in `hosts/nixlaptop/default.nix`. Logins go through Tailscale SSH, so there are no builder keys to manage.
