---
name: nixos-config-patterns
description: Coding patterns for Justin's NixOS configuration
version: 1.0.0
source: local-git-analysis
analyzed_commits: 50
---

# NixOS Configuration Patterns

## Repository Structure

```
nixos-config/
├── flake.nix                    # Entry point with mkHost helper
├── main/configuration.nix       # Shared base system config
├── hosts/
│   ├── nixpc/                   # Desktop (NVIDIA, gaming)
│   └── nixlaptop/               # ThinkPad T14 (fingerprint, power mgmt)
├── modules/
│   ├── core/                    # Shared system modules (auto-imported)
│   │   ├── default.nix
│   │   ├── cli-packages.nix     # CLI tools
│   │   ├── programs.nix         # GUI applications
│   │   ├── services.nix         # System services
│   │   └── fonts.nix            # Font packages
│   ├── extras/                  # Feature modules with options
│   │   ├── default.nix
│   │   ├── gaming.nix           # modules.gaming.enable
│   │   ├── fingerprint.nix      # modules.fingerprint.enable
│   │   ├── compscijava.nix      # modules.compscijava.enable
│   │   ├── niri-system.nix      # Wayland/Niri tools
│   │   ├── quickshell.nix       # QuickShell bar
│   │   └── lockscreen.nix       # Lock screen deps
│   ├── services/                # Service configuration
│   │   └── portals.nix          # XDG portals, polkit
│   ├── programs/                # Program-specific config
│   │   ├── nixvim.nix
│   │   ├── spicetify.nix
│   │   └── nixcord.nix
│   └── theming/
│       └── stylix.nix           # Theme configuration
├── home-manager/justin/         # User configuration
├── configs/                     # Dotfiles (symlinked)
│   ├── niri/                    # Niri WM config
│   ├── quickshell/              # QuickShell QML
│   └── waybar/                  # Waybar config
├── assets/wallpapers/           # Wallpaper collection
└── scripts/
    ├── rebuild.sh               # ./scripts/rebuild.sh <host>
    └── update.sh                # ./scripts/update.sh <host>
```

## Module Patterns

### Adding a CLI Tool
1. Edit `modules/core/cli-packages.nix`
2. Add package to appropriate section (Shell, Dev, Media, etc.)
3. Rebuild

### Adding a GUI Application
1. Edit `modules/core/programs.nix`
2. Add to `environment.systemPackages`
3. Rebuild

### Adding an Optional Feature
Create option-based module in `modules/extras/`:

```nix
{ config, lib, pkgs, ... }:
{
  options.modules.myfeature.enable = lib.mkEnableOption "description";

  config = lib.mkIf config.modules.myfeature.enable {
    environment.systemPackages = [ ... ];
  };
}
```

Enable per-host in `flake.nix`:
```nix
hostModules = [
  { modules.myfeature.enable = true; }
];
```

### Adding a Flake Input
1. Add input to `flake.nix` inputs section
2. Add to outputs function parameters if needed
3. Reference via `inputs.name.packages.${pkgs.system}.default`

## File Co-Change Patterns

| When Changing | Also Update |
|---------------|-------------|
| QuickShell UI | `Theme.qml`, `shell.qml`, affected modules |
| Niri keybinds | `configs/niri/keybind.kdl` |
| New package | `modules/core/cli-packages.nix` or `programs.nix` |
| New service | `modules/core/services.nix` or create new module |
| Flake inputs | `flake.nix` inputs + outputs |

## Commit Patterns

This repository uses descriptive commit messages:
- "Added X" - New feature/package
- "Fixed X" - Bug fix
- "Modified X" - Changes to existing
- "Testing X" - Experimental changes

## Workflows

### Adding a New Host
1. Create `hosts/newhostname/`
   - `hardware-configuration.nix` (from `nixos-generate-config`)
   - `networking.nix` (hostname)
   - Host-specific modules (gpu.nix, laptop.nix)
2. Add to `flake.nix`:
```nix
newhostname = mkHost {
  hostModules = [
    ./hosts/newhostname/hardware-configuration.nix
    ./hosts/newhostname/networking.nix
    { modules.feature.enable = true; }
  ];
};
```
3. Create rebuild script or use `./scripts/rebuild.sh newhostname`

### Modifying QuickShell
1. Edit QML files in `configs/quickshell/`
2. Changes apply immediately (live reload)
3. For new modules, update `qmldir` files
4. Test with `qs ipc call quickshell-bar <method>`

### Testing Configuration
```bash
# Check syntax
nix flake check

# Build without switching
nix build .#nixosConfigurations.nixlaptop.config.system.build.toplevel

# Rebuild and switch
./scripts/rebuild.sh nixlaptop
```

## QuickShell IPC Commands

```bash
qs ipc call quickshell-bar lockscreen    # Lock screen
qs ipc call quickshell-bar wakelock      # Wake from lock
qs ipc call quickshell-bar toggle-cc     # Toggle control center
qs ipc call quickshell-bar toggle-power  # Toggle power menu
```

## Key Files

| Purpose | File |
|---------|------|
| Add CLI package | `modules/core/cli-packages.nix` |
| Add GUI app | `modules/core/programs.nix` |
| Wayland tools | `modules/extras/niri-system.nix` |
| System services | `modules/core/services.nix` |
| XDG portals | `modules/services/portals.nix` |
| Theme | `modules/theming/stylix.nix` |
| User config | `home-manager/justin/home.nix` |
| Feature flags | `modules/extras/*.nix` |
