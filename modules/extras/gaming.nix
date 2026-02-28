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


  environment.systemPackages = [
    # Minecraft
    pkgs.prismlauncher
    pkgs.gamescope

  ];
}
