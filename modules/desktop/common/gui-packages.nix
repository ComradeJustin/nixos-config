{ config, lib, pkgs, ... }:
{
  options.modules.gui-packages.enable = lib.mkEnableOption "GUI applications (Ghostty, VS Code, Firefox, Nautilus)";

  config = lib.mkIf config.modules.gui-packages.enable {
    programs.wireshark.enable = true;
    programs.firefox.enable = true;

    environment.systemPackages = with pkgs; [
      ghostty
      vscode
      nautilus
      feh
      nmap
      ethtool
    ];
  };
}
