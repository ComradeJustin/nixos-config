# The niri compositor and the Wayland utilities its config calls.
{ pkgs, ... }:
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
    sway-audio-idle-inhibit
  ];
}
