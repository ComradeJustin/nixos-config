{ config, lib, pkgs, ... }:
{
  options.modules.niri.enable = lib.mkEnableOption "Niri window manager and Wayland utilities";

  config = lib.mkIf config.modules.niri.enable {
    # So tuigreet's session list includes niri alongside driftwm.
    services.displayManager.sessionPackages = [ pkgs.niri ];

    environment.systemPackages = with pkgs; [
      niri

      wl-clipboard
      cliphist
      rofi
      xwayland-satellite
      wev

      awww

      brightnessctl
      playerctl
    ];
  };
}
