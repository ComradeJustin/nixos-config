{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  environment.pathsToLink = [
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];
  environment.systemPackages = [
    pkgs.seahorse
    pkgs.hyprpolkitagent
  ];

  xdg.portal = {
    enable = true;
  };
}
