{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    waybar
    niri
    nixfmt
  ];
}
