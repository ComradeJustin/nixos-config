---
name: disko-grub-duplicate-device
description: "Disko EF02 partition auto-adds grub device; avoid duplicate with boot module"
user-invocable: false
origin: auto-extracted
---

# Disko + GRUB Duplicate Device Conflict

**Extracted:** 2026-03-30
**Context:** Using disko for declarative disk partitioning alongside a NixOS boot loader module

## Problem
When a disko `disk-config.nix` includes a partition with `type = "EF02"` (BIOS boot),
disko automatically adds that disk to `boot.loader.grub.devices`. If your NixOS config
also sets `boot.loader.grub.device` to the same disk (e.g. via `modules.boot.grubDevice`),
you get:

```
error: Failed assertions:
- You cannot have duplicated devices in mirroredBoots
```

## Solution
Let only ONE system manage GRUB device installation:

**Option A (recommended):** Remove the `EF02` partition from disko. Let your boot module
handle `boot.loader.grub.device`. Disko only manages data partitions (root, swap, etc.).

```nix
# disk-config.nix — NO boot partition
disko.devices.disk.main = {
  device = "/dev/sda";
  type = "disk";
  content = {
    type = "gpt";
    partitions = {
      root = { end = "-4G"; content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; }; };
      swap = { size = "4G"; content = { type = "swap"; }; };
    };
  };
};
```

**Option B:** Include `EF02` in disko and remove `grub.device` from your boot module
(let disko be the sole GRUB installer).

## When to Use
- Adding a new disko-managed host with GRUB (MBR or BIOS boot)
- Seeing "duplicated devices in mirroredBoots" error after adding disko
- Combining disko with a centralized boot loader module
