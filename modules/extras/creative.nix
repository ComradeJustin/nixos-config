{ config, lib, pkgs, ... }:
{
  options.modules.creative.enable = lib.mkEnableOption "creative apps (Krita, GIMP, OpenTabletDriver)";

  config = lib.mkIf config.modules.creative.enable {
    environment.systemPackages = with pkgs; [
      krita
      gimp
      opentabletdriver
    ];
  };
}
