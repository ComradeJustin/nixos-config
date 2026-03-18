---
name: nixos-config-patterns
description: "NixOS configuration patterns for multi-host setups with QuickShell desktop"
version: 1.0.0
source: local-git-analysis
analyzed_commits: 60
user-invocable: false
---

# NixOS Configuration Patterns

Patterns extracted from this NixOS configuration repository for managing multi-host systems with a QuickShell-based desktop environment.

## Repository Structure

```
nixos-config/
├── flake.nix                    # Main flake with inputs and host definitions
├── main/configuration.nix       # Shared base configuration
├── hosts/
│   ├── nixpc/                   # Desktop-specific (GPU, networking)
│   └── nixlaptop/               # Laptop-specific (power, fingerprint)
├── modules/
│   ├── core/                    # Always-enabled modules (packages, fonts, services)
│   ├── extras/                  # Optional feature modules with enable flags
│   ├── services/                # System services (portals, etc.)
│   ├── programs/                # Application-specific configs
│   └── theming/                 # Stylix and visual theming
├── home-manager/justin/         # User-specific home-manager config
└── configs/
    ├── quickshell/              # QuickShell desktop shell
    ├── niri/                    # Niri window manager config
    └── ghostty/                 # Terminal emulator config
```

## NixOS Module Patterns

### Feature Toggle Module Pattern

Optional modules in `modules/extras/` use this pattern:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.modules.featureName;
in
{
  options.modules.featureName = {
    enable = lib.mkEnableOption "Feature description";

    # Optional sub-features
    features = {
      subFeature = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Sub-feature description";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Conditional warnings for dependencies
    warnings = lib.optionals (cfg.features.subFeature && !someCondition) [
      "Warning message about missing dependency"
    ];

    environment.systemPackages = with pkgs;
      [ /* base packages */ ]
      ++ lib.optionals cfg.features.subFeature [ /* conditional packages */ ];

    # Enable required services
    services.someService.enable = true;
  };
}
```

### Multi-Host Flake Pattern

The `flake.nix` uses a helper function for consistent host definitions:

```nix
let
  sharedModules = [
    ./main/configuration.nix
    ./modules/core
    ./modules/extras
    # ... shared modules
    {
      # Default feature flags for all hosts
      modules.featureName.enable = true;
    }
  ];

  mkHost = { hostModules }:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = sharedModules ++ hostModules;
    };
in
{
  nixosConfigurations = {
    nixpc = mkHost {
      hostModules = [
        ./hosts/nixpc/hardware-configuration.nix
        ./hosts/nixpc/gpu.nix
        { modules.gaming.enable = true; }  # Host-specific features
      ];
    };
    nixlaptop = mkHost {
      hostModules = [
        ./hosts/nixlaptop/hardware-configuration.nix
        { modules.fingerprint.enable = true; }
      ];
    };
  };
}
```

### Flake Input Pattern

All external flake inputs follow the `nixpkgs.follows` pattern:

```nix
inputs = {
  nixpkgs.url = "nixpkgs/nixos-unstable";

  some-flake = {
    url = "github:owner/repo";
    inputs.nixpkgs.follows = "nixpkgs";  # Always add this
  };
};
```

## QuickShell Architecture

### Component Structure

```
configs/quickshell/
├── shell.qml              # Entry point, instantiates all services
├── Theme.qml              # Centralized theming (colors, fonts, icons)
├── modules/
│   ├── Bar.qml            # Main status bar
│   ├── ControlCenter.qml  # Settings/notification panel
│   ├── PowerMenu.qml      # Shutdown/restart menu
│   ├── Spotlight.qml      # App launcher overlay
│   ├── Osd.qml            # On-screen display (volume, brightness)
│   ├── LockScreen.qml     # Lock screen UI
│   ├── barmodules/        # Individual bar widgets
│   │   └── *.qml          # NetworkModule, AudioModule, etc.
│   └── spotlight/         # Spotlight sub-views
│       └── *.qml          # LauncherView, ClipboardView, etc.
└── utils/
    └── *Service.qml       # Backend services (Audio, Wifi, Bluetooth, etc.)
```

### Service Pattern

Services in `utils/` follow this pattern:

```qml
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    // Public properties for UI binding
    property bool connected: false
    property string status: ""
    property var items: ListModel {}

    // Initialization
    Component.onCompleted: statusProc.running = true

    // Status polling process
    Process {
        id: statusProc
        command: ["bash", "-c", "command here"]
        stdout: SplitParser {
            onRead: data => {
                // Parse and update properties
            }
        }
        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: 10000
        onTriggered: statusProc.running = true
    }

    // Public functions
    function refresh() { scanProc.running = true; }
    function toggle() { /* implementation */ }
}
```

### Bar Module Pattern

Bar modules in `barmodules/` follow this pattern:

```qml
import QtQuick
import QtQuick.Layouts
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    // Required service reference
    property var someService: null

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: theme.iconName
            color: theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
        }

        Text {
            text: root.someService ? root.someService.status : "--"
            color: theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.fontSize }
        }
    }
}
```

### Command Injection Prevention

Always use array-based Process commands to prevent shell injection:

```qml
// SAFE - Array syntax prevents injection
Process {
    property string userInput: ""
    command: ["nmcli", "dev", "wifi", "connect", userInput]
}

// SAFE - Positional parameters for complex commands
Process {
    property string mac: ""
    command: ["sh", "-c", "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\"", "--", mac]
}

// UNSAFE - String interpolation allows injection
Process {
    command: ["bash", "-c", "nmcli connect " + userInput]  // DON'T DO THIS
}
```

## Workflows

### Adding a New Optional Module

1. Create `modules/extras/feature-name.nix` with enable option
2. Import in `modules/extras/default.nix`
3. Enable per-host in `flake.nix` hostModules

### Adding a New QuickShell Service

1. Create `configs/quickshell/utils/FeatureService.qml`
2. Register in `configs/quickshell/utils/qmldir`
3. Instantiate in `configs/quickshell/shell.qml`
4. Pass to modules that need it

### Adding a New Bar Module

1. Create `configs/quickshell/modules/barmodules/FeatureModule.qml`
2. Register in `configs/quickshell/modules/barmodules/qmldir`
3. Add to Bar.qml with service binding

## Host-Specific Patterns

### Desktop (nixpc)
- GPU configuration in `hosts/nixpc/gpu.nix`
- Gaming module enabled
- No power management needed

### Laptop (nixlaptop)
- Power/thermal management in `hosts/nixlaptop/laptop.nix`
- Fingerprint, Bluetooth modules enabled
- Uses nixos-hardware for ThinkPad optimizations

## Validation Commands

```bash
# Check flake validity
nix flake check --no-build

# Build specific host
nix build .#nixosConfigurations.nixlaptop.config.system.build.toplevel

# Evaluate module options
nix eval --json '.#nixosConfigurations.nixlaptop.config.modules.quickshell.features'
```
