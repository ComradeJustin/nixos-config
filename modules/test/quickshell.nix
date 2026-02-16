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
}
