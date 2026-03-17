{ config, inputs, lib, pkgs, ... }:
{
  options.modules.niri.enable = lib.mkEnableOption "Niri window manager and Wayland utilities";

  config = lib.mkIf config.modules.niri.enable {
    environment.systemPackages = with pkgs; [
      # Window manager
      inputs.niri-beta.packages.${pkgs.system}.niri
      waybar

      # Wayland utilities
      wl-clipboard
      cliphist
      rofi
      xwayland-satellite
      wev

      # Wallpaper
      inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww

      # Media/input control
      brightnessctl
      playerctl
    ];
  };
}
