{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  programs.niri.enable = true;
  environment.systemPackages = with pkgs; [
    waybar
    nixfmt
    dunst
    brightnessctl
    wev
  ];
  
}
