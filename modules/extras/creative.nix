{ config, lib, pkgs, ... }:
{
  options.modules.creative.enable = lib.mkEnableOption "creative apps (Krita, GIMP, OpenTabletDriver)";

  config = lib.mkIf config.modules.creative.enable {
    hardware.opentabletdriver.enable = true;
    hardware.opentabletdriver.daemon.enable = true;

    environment.systemPackages = with pkgs; [
      krita
      gimp
    ];
  };
}
