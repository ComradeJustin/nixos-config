{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # Steam games
  programs.steam = {
    enable = true;
  };

  # Non steam games

  environment.systemPackages = [
    pkgs.prismlauncher
  ];
}
