---
name: nixos-pam-rules-override
description: "Override PAM module args in NixOS via rules.auth.<module>.args when options aren't exposed"
user-invocable: false
origin: auto-extracted
---

# NixOS PAM Module Argument Override

**Extracted:** 2026-03-25
**Context:** Customizing pam_fprintd timeout/retries for a QuickShell lockscreen

## Problem
NixOS PAM service options like `fprintAuth = true` don't expose module-specific
arguments (e.g., `timeout`, `max-tries` for pam_fprintd). The generated PAM config
uses hardcoded defaults (30s timeout, 3 retries).

## Solution
Use the (hidden) `rules.auth.<module>.args` attribute to inject custom arguments:

```nix
security.pam.services.quickshell-bar = {
  fprintAuth = true;
  rules.auth.fprintd.args = [ "timeout=-1" "max-tries=-1" ];
};
```

This generates:
```
auth sufficient pam_fprintd.so timeout=-1 max-tries=-1
```

The `rules` option is marked `visible = false` in the NixOS PAM module source
(`nixos/modules/security/pam.nix`) but is fully functional. Each PAM module entry
has a `name` field (e.g., `"fprintd"`, `"unix"`, `"deny"`) that becomes the
attribute key under `rules.auth`.

### Available pam_fprintd args
- `timeout=SECONDS` — Time before auth failure (default: 30, use -1 for no limit)
- `max-tries=N` — Fingerprint attempts before failure (default: 3, use -1 for unlimited)
- `debug` — Enable debug logging to systemd journal

## Gotcha: PAM Service Name Must Match
The QuickShell lockscreen PamContext must reference the correct PAM service:

```qml
PamContext {
    config: "quickshell-bar"  // Must match the NixOS PAM service name
    // NOT "login" — that's a different service with different args
}
```

Check `/etc/pam.d/<service>` to verify args were applied after rebuild.

## When to Use
- Customizing PAM module behavior per-service on NixOS
- Any pam_fprintd, pam_u2f, pam_oath tuning where NixOS doesn't expose options
- Debugging lockscreen auth issues (check service name match first)
