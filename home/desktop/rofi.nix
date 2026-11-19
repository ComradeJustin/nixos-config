# Rofi application launcher.
{ pkgs, ... }:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    settings = {
      modes = [
        "drun"
        "run"
        "window"
        "ssh"
      ];
      show-icons = true;
    };
  };
}
