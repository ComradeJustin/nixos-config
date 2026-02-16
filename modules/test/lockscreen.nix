{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
  environment.systemPackages = with pkgs; [
    inputs.apple-fonts.packages.${pkgs.system}
  ];
}
