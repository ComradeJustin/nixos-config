{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;

  fonts.packages = with pkgs; [
    inputs.apple-fonts.packages.${pkgs.system}.sf-pro-nerd
  ];
}
