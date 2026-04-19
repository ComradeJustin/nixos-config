{ config, lib, pkgs, ... }:
{
  options.modules.smb-client.enable = lib.mkEnableOption "SMB/CIFS client tools";

  config = lib.mkIf config.modules.smb-client.enable {
    environment.systemPackages = [ pkgs.cifs-utils ];
  };
}
