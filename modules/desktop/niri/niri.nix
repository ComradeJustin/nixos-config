{ config, inputs, lib, pkgs, ... }:
{
  options.modules.niri.enable = lib.mkEnableOption "Niri window manager and Wayland utilities";

  config = lib.mkIf config.modules.niri.enable {
    environment.systemPackages = with pkgs; [
      inputs.niri.packages.${pkgs.system}.niri

      wl-clipboard
      cliphist
      rofi
      xwayland-satellite
      wev

      inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww

      brightnessctl
      playerctl
    ];
  };
}
