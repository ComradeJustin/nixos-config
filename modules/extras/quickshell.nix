{ config, inputs, lib, pkgs, ... }:
{
  options.modules.quickshell.enable = lib.mkEnableOption "QuickShell status bar and widgets";

  config = lib.mkIf config.modules.quickshell.enable {
    environment.systemPackages = with pkgs; [
      inputs.qml-niri.packages.${pkgs.system}.quickshell
      libsForQt5.qt5.qtgraphicaleffects
      kdePackages.qt5compat
      cava  # Audio visualizer for media popup
    ];
    services.upower.enable = true;
  };
}
