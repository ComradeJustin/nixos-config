{ config, lib, pkgs, ... }:
{
  options.modules.portals.enable = lib.mkEnableOption "XDG portals, polkit, GNOME keyring";

  config = lib.mkIf config.modules.portals.enable {
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

    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    environment.systemPackages = [
      pkgs.seahorse
      # NOTE: polkit_gnome is intentionally NOT in systemPackages. The explicit
      # user service above references its binary by store path, so it stays in
      # the closure regardless. Adding it here also installs its
      # /etc/xdg/autostart/*.desktop, which systemd-xdg-autostart-generator turns
      # into a second agent (app-polkit-gnome...@autostart.service). That duplicate
      # wins the registration race and makes our explicit service fail
      # ("agent already exists"). One launcher only.
    ];

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
      ];
      config = {
        common = {
          default = [ "gnome" "gtk" ];
        };
      };
    };
  };
}
