{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{

 
  environment.systemPackages = with pkgs; [
    inputs.niri-beta.packages.${pkgs.system}.niri
    waybar
    nixfmt
    dunst
    brightnessctl
    wev
    wineWowPackages.waylandFull
    playerctl
  ];

}
