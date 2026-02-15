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
  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;
  security.pam.services.hyprpolkitagent.fprintAuth = true;
  environment.systemPackages = [
    pkgs.seahorse
    pkgs.hyprpolkitagent
  ];

  xdg.portal = {
    enable = true;
  };
}
