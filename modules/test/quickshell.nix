{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    inputs.qml-niri.packages.${pkgs.system}.quickshell
    libsForQt5.qt5.qtgraphicaleffects
    kdePackages.qt5compat
  ];
  services.upower.enable = true;
}
