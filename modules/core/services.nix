{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{

  environment.systemPackages = [
    inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww
    pkgs.wiremix
    pkgs.rofi
  ];
  # Services
  services.flatpak.enable = true;

  services.gvfs.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "greeter";
      };
    };

  };
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal"; # Without this errors will spam on screen
    # Without these bootlogs will spam on screen
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };
}
