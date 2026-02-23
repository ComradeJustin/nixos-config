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
  services.flatpak.enable = true;
  
  environment.systemPackages = [
    # Minecraft
    pkgs.prismlauncher
    pkgs.gamescope

  ];
}
