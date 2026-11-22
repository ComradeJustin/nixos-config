# XDG portals (file pickers, screen sharing), polkit and the GNOME keyring.
{ pkgs, ... }:
{
  environment.pathsToLink = [
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];
  services.gnome.gnome-keyring.enable = true;
  # Provides the ScreenCast impl that xdg-desktop-portal-gnome delegates to.
  # Required when running under non-GNOME compositors (e.g. niri) so that
  # ScreenCast portal requests get serviced without gnome-shell running.
  services.gnome.gnome-remote-desktop.enable = true;
  security.polkit.enable = true;

  # Password prompts for administrator rights come from the desktop shell
  # (configs/shell), which registers itself as the session's polkit agent.
  # Only one agent can register, so no other one is started here.

  environment.systemPackages = [
    pkgs.seahorse
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      common = {
        default = [
          "gnome"
          "gtk"
        ];
      };
    };
  };
}
