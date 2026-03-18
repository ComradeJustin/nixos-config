{ config, inputs, lib, pkgs, ... }:
let
  cfg = config.modules.quickshell;
in
{
  options.modules.quickshell = {
    enable = lib.mkEnableOption "QuickShell status bar and widgets";

    features = {
      weather = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable weather widget (requires internet)";
      };

      bluetooth = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Bluetooth controls in control center";
      };

      clipboard = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable clipboard history manager";
      };

      mediaControls = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable media playback controls and visualizer";
      };

      brightness = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable brightness controls (for laptops)";
      };

      audio = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable audio controls and per-app volume mixer";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Warnings for feature dependencies (non-fatal)
    warnings = lib.optionals (cfg.features.bluetooth && !(config.modules.bluetooth.enable or false)) [
      "QuickShell bluetooth feature is enabled but modules.bluetooth.enable is not set. Bluetooth controls may not work."
    ];

    environment.systemPackages = with pkgs;
      [
        # ── Core QuickShell ──
        inputs.qml-niri.packages.${pkgs.system}.quickshell
        libsForQt5.qt5.qtgraphicaleffects
        kdePackages.qt5compat
      ]
      # ── Audio feature ──
      ++ lib.optionals cfg.features.audio [
        pipewire      # Provides: pw-dump, pw-cli for audio stream detection
        wireplumber   # Provides: wpctl for volume control
        jq            # Required for pw-dump JSON parsing
      ]
      # ── Clipboard feature ──
      # Note: Also provided by niri-system.nix if modules.niri.enable = true
      ++ lib.optionals cfg.features.clipboard [
        wl-clipboard  # Provides: wl-copy, wl-paste
        cliphist      # Clipboard history daemon
      ]
      # ── Media controls feature ──
      ++ lib.optionals cfg.features.mediaControls [
        cava          # Audio visualizer for media popup
        playerctl     # Media player control (also in niri-system)
      ]
      # ── Brightness feature ──
      # Note: Also provided by niri-system.nix if modules.niri.enable = true
      ++ lib.optionals cfg.features.brightness [
        brightnessctl  # Backlight control for laptops
      ]
      # ── Weather feature ──
      ++ lib.optionals cfg.features.weather [
        curl  # HTTP requests to weather API
      ];

    # ── Required services ──
    services.upower.enable = true;  # Battery information for bar

    # Ensure PipeWire is available for audio features
    # (Usually already enabled via services.pipewire in main config)
  };
}
