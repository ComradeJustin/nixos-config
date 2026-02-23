{

  lib,
  pkgs,
  ...
}:
{

  programs.ssh.enableAskPassword = false;
  programs.firefox.enable = true;
  environment.systemPackages = with pkgs; [
    ghostty
    vscode
    waybar
    nautilus
    cliphist
  ];

  imports = [
    ../programs/spicetify.nix
    ../programs/nixcord.nix
    ../../configs/stylix/config.nix
  ];
}
