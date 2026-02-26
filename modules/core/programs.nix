{

  lib,
  pkgs,
  ...
}:
{

  programs.ssh.enableAskPassword = false;
  programs.wireshark.enable = true;
  programs.firefox.enable = true;
  environment.systemPackages = with pkgs; [
    ghostty
    vscode
    waybar
    nautilus
    wireshark
    cliphist
  ];

  imports = [
    ../programs/spicetify.nix
    ../programs/nixcord.nix
    ../../configs/stylix/config.nix
  ];
}
