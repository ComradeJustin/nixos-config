{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{

  environment.systemPackages = with pkgs; [
    nushell
    carapace
    vim
    wget
    git
    nitch
    lazygit
    fastfetch
    btop
    gtk4
    xwayland-satellite
    ffmpeg
    gcc
    cava
    fzf
    ani-cli
    unzip
    inputs.lobster.packages.${pkgs.system}.lobster
  ];
  # Non steam games
  services.flatpak.enable = true;

}
