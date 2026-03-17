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
    nautilus
    krita

    # Network tools
    wireshark
    nmap
  ];

  imports = [
    ../programs/spicetify.nix
    ../programs/nixcord.nix
  ];
}
