{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    vim
    wget  
    git
    neovim
    nitch
    lazygit
    fastfetch
    btop
    gtk4
    xwayland-satellite
  ];


}
