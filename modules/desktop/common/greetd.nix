{ config, lib, pkgs, ... }:
{
  options.modules.greetd.enable = lib.mkEnableOption "greetd login manager, Xserver, printing, gvfs";

  config = lib.mkIf config.modules.greetd.enable {
    services.xserver = {
      enable = true;
      autoRepeatDelay = 200;
      autoRepeatInterval = 35;
    };

    services.gvfs.enable = true;

    services.printing.enable = true;
    services.printing.drivers = with pkgs; [ gutenprint hplip ];
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    services.flatpak.enable = true;
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          # niri-session stays the command tuigreet runs. --sessions is where
          # driftwm's desktop file lands, so it can be selected at login.
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
          user = "greeter";
        };
      };
    };
    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };
  };
}
