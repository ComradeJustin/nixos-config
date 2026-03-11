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
    brightnessctl
    wev
    wineWowPackages.waylandFull
    playerctl
  ];

}
