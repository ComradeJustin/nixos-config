{

  lib,
  pkgs,
  ...
}:
{

  programs.niri.enable = true;
  programs.firefox.enable = true;
  environment.systemPackages = with pkgs;[
    ghostty
    vscode
    waybar
    nautilus
  ];

  imports = [
    ./programs/spicetify.nix
    ./programs/nixcord.nix
    ../configs/stylix/config.nix
  ];
}
