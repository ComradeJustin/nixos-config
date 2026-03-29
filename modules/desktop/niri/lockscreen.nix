{ config, lib, pkgs, ... }:
{
  options.modules.lockscreen.enable = lib.mkEnableOption "Swayidle lock screen support";

  config = lib.mkIf config.modules.lockscreen.enable {
    environment.systemPackages = [
      pkgs.swayidle
      pkgs.sway-audio-idle-inhibit
    ];
  };
}
