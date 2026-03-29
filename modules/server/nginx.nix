{ config, lib, ... }:
{
  options.modules.nginx.enable = lib.mkEnableOption "Nginx reverse proxy";

  config = lib.mkIf config.modules.nginx.enable {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
