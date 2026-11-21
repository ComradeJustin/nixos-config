# NixOS Config

Multi-machine NixOS configuration with shared binary cache and distributed builds.

## Machines

| Host | Role | Location |
|------|------|----------|
| **nixpc** | Headless server (binary cache, AdGuard DNS, exit node, samba, website), remote builder | Always-on |
| **nixlaptop** | Desktop, build client | Local network |

## Layout

```
flake.nix            inputs, the two hosts and the dev shells
hosts/<name>/        default.nix imports every module that machine uses;
                     the other files are that machine's own hardware
modules/base.nix     what every machine gets (Nix settings, user, SSH, CLI tools)
modules/editor.nix   Neovim (nvf)
modules/tailscale.nix
modules/desktop/     the graphical desktop, one file per part (niri, audio, theme...)
modules/server/      services nixpc runs, one file each (AdGuard, Harmonia, Samba, website)
home/base.nix        Home Manager for every machine (shell, git, prompt)
home/desktop/        Home Manager for desktop machines: apps.nix lists GUI apps,
                     and each configured program has its own file
shells/              dev shells
```

Importing a module turns it on; there are no enable flags. To see what a machine runs, read its `hosts/<name>/default.nix`.

Where to add a program:

- every machine: `environment.systemPackages` in `modules/base.nix`
- a GUI app: `home.packages` in `home/desktop/apps.nix`
- a GUI app that needs settings: a new file in `home/desktop/`, added to the imports in `home/desktop/default.nix`
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

## Dev shells

`ctf`, `rust` and `cuda` open development environments defined in `shells/` (the aliases run `nix develop ~/nixos-config#<name>`). They use this flake's lock file, so they get the same package versions as the systems.

The `cuda` shell is for nixpc. Its packages are the CUDA builds from `cache.nixos-cuda.org`, so nothing is compiled locally. To add a CUDA program, add it to `shells/cuda.nix`.

## Binary Cache (Harmonia)

nixpc runs [Harmonia](https://github.com/nix-community/harmonia) on port 5000, serving signed store paths to the tailnet.

### How it works

1. **nixpc** generates a signing keypair on first boot (`/var/lib/harmonia/cache-key.pem`). The private key never leaves nixpc.
2. Client machines allow `http://nixpc:5000` as a cache (see `hosts/nixlaptop/default.nix`). It is not on by default, so commands never wait on it when nixpc is down; `rebuild.sh` turns it on when nixpc answers
3. After each local rebuild, `rebuild.sh` copies the result to nixpc's store. Harmonia signs paths as it serves them.

### Adding a new machine to the cache

Copy the `nix.settings.trusted-substituters` and `trusted-public-keys` lines from `hosts/nixlaptop/default.nix` into the new host's `default.nix`.

### Manual operations

```bash
# Check cache is working
curl http://nixpc:5000/nix-cache-info

# Push current system to cache
nix copy --no-check-sigs --to ssh-ng://justin@nixpc $(readlink -f /run/current-system)

# View the public key (on nixpc)
sudo cat /var/lib/harmonia/cache-key.pub
```

## Secrets

No secrets are stored in this repository. The ones that exist are files on nixpc, and the config only names their paths:

| File on nixpc | What it is | How it gets there |
|---|---|---|
| `/var/lib/cloudflared/token` | Cloudflare Tunnel token for the website | Placed by hand (mode 600) |
| `/var/lib/harmonia/cache-key.pem` | Binary cache signing key | Generated on first boot |

## Distributed Builds

nixpc acts as a remote builder. When scripts detect it's online, they limit local jobs to 4 so nix offloads work to nixpc.

The client side is the `nix.buildMachines` block in `hosts/nixlaptop/default.nix`. Logins go through Tailscale SSH, so there are no builder keys to manage.
