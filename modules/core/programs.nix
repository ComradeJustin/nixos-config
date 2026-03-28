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
    feh
    # Network tools
    wireshark
    nmap
    ethtool
  ];
}
