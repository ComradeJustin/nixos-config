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
    # GUI Applications
    ghostty
    vscode
    gimp
    nautilus
    krita

    # Network tools
    wireshark
    nmap
    ethtool
  ];

  imports = [
    ../programs/spicetify.nix
    ../programs/nixcord.nix
  ];
}
