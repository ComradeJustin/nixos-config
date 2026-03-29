{ config, lib, ... }:
{
  options.modules.monitoring.enable = lib.mkEnableOption "Prometheus node exporter for monitoring";

  config = lib.mkIf config.modules.monitoring.enable {
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" "processes" ];
    };
  };
}
