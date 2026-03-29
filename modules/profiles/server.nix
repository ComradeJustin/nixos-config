{ config, lib, ... }:
{
  options.modules.profiles.server.enable = lib.mkEnableOption "server profile (sensible server defaults)";

  config = lib.mkIf config.modules.profiles.server.enable {
    modules.hosts.headless.enable = lib.mkDefault true;
  };
}
