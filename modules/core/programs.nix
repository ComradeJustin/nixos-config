{

  lib,
  pkgs,
  inputs,
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
    inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  imports = [
    ../programs/spicetify.nix
    ../programs/nixcord.nix
    ../../configs/stylix/config.nix
  ];
}
