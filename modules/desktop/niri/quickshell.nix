{ config, inputs, lib, pkgs, ... }:
let
  cfg = config.modules.quickshell;
in
{
  options.modules.quickshell = {
    enable = lib.mkEnableOption "QuickShell status bar and widgets";

    # The QML shell reads its own runtime config — these only gate package installs.
    features = {
      mediaControls = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable media playback controls and visualizer (installs cava)";
      };

      nightLight = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Night Light (installs wlsunset)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Packages already provided by niri.nix: wl-clipboard, cliphist, brightnessctl, playerctl
    # Packages already provided by greetd.nix: pipewire, wireplumber (as services)
    # Packages already provided by cli-packages.nix: curl, jq
    environment.systemPackages = with pkgs;
      [
        glib
        inputs.qml-niri.packages.${pkgs.system}.quickshell
        qt5.qtgraphicaleffects
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
