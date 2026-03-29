---
name: nixos-mkmerge-nullor-pitfall
description: "mkMerge with nullOr options inside mkIf causes 'expected a set but found null' — flatten instead"
user-invocable: false
origin: auto-extracted
---

# NixOS mkMerge + nullOr Causes Null Config Error

**Extracted:** 2026-03-28
**Context:** Writing option-gated NixOS modules with nullable override options

## Problem
Using `lib.mkMerge` with `lib.mkIf (x != null)` guards inside an outer `lib.mkIf` produces the cryptic error:
```
error: expected a set but found null: null
```
The error trace points to nixpkgs internals (`modules.nix:835`) with no indication of which module file is broken.

## Broken Pattern
```nix
config = lib.mkIf cfg.enable (lib.mkMerge [
  { environment.systemPackages = cfg.packages; }
  (lib.mkIf (cfg.kernel != null) {
    boot.kernelPackages = cfg.kernel;
  })
  (lib.mkIf (cfg.bootloader != null) {
    boot.loader = cfg.bootloader;
  })
]);
```

## Solution
Flatten — use `mkIf` on individual attributes instead of wrapping entire attrsets in `mkMerge`:
```nix
config = lib.mkIf cfg.enable {
  environment.systemPackages = cfg.packages;
  boot.kernelPackages = lib.mkIf (cfg.kernel != null) cfg.kernel;
};
```

## Debugging Tip
The error gives no file path. Binary-search by commenting out imports in `default.nix` to isolate the broken module.

## When to Use
- Writing NixOS modules with `nullOr` options that conditionally set config
- Debugging "expected a set but found null" errors during `nix flake check`
