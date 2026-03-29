{ config, lib, ... }:
{
  options.modules.networking.enable = lib.mkEnableOption "NetworkManager" // { default = true; };

  config = lib.mkIf config.modules.networking.enable {
    networking.networkmanager.enable = true;
  };
}
