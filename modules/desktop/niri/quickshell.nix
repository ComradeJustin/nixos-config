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

      nightLight = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Night Light (blue-light reduction via wlsunset)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optionals (cfg.features.bluetooth && !(config.modules.bluetooth.enable or false)) [
      "QuickShell bluetooth feature is enabled but modules.bluetooth.enable is not set. Bluetooth controls may not work."
    ];

    # Packages already provided by niri.nix: wl-clipboard, cliphist, brightnessctl, playerctl
    # Packages already provided by greetd.nix: pipewire, wireplumber (as services)
    # Packages already provided by cli-packages.nix: curl, jq
    environment.systemPackages = with pkgs;
      [
        inputs.qml-niri.packages.${pkgs.system}.quickshell
        libsForQt5.qt5.qtgraphicaleffects
        kdePackages.qt5compat
        inotify-tools
        imagemagick
      ]
      ++ lib.optionals cfg.features.mediaControls [
        cava
      ]
      ++ lib.optionals cfg.features.nightLight [
        wlsunset
      ];

    services.upower.enable = true;

    # PAM service for lock screen authentication
    # fingerprint.nix extends this with fprintAuth when available
    security.pam.services.quickshell-bar = {};
  };
}
