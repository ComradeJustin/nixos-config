{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    inputs.qml-niri.packages.${pkgs.system}.quickshell
  ];
  services.upower.enable = true;
}
