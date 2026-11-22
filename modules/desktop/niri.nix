# The niri compositor and the Wayland utilities its config calls.
{ lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    niri

    wl-clipboard
    cliphist
    xwayland-satellite
    wev

    awww

    brightnessctl
    playerctl

    # Idle handling and lock screen support
    swayidle
  ];

  # Keeps the screen awake while audio is playing. It aborts every day or so,
  # and when niri started it with spawn-at-startup nothing brought it back, so
  # the screen then dimmed and locked during videos. As a service it restarts.
  systemd.user.services.sway-audio-idle-inhibit = {
    description = "Keep the screen awake while audio is playing";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = lib.getExe pkgs.sway-audio-idle-inhibit;
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
