{ config, lib, ... }:
{
  options.modules.monitoring.enable = lib.mkEnableOption "Prometheus + node exporter metrics collection";

  config = lib.mkIf config.modules.monitoring.enable {
    # ── Node exporter (metrics collection) ──
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" "processes" ];
    };

    # ── Prometheus (metrics storage + scraping) ──
    services.prometheus = {
      enable = true;
      port = 9090;
      retentionTime = "30d";
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            { targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; labels.host = config.networking.hostName; }
          ];
        }
      ];
    };

    # Grafana removed: it was exposed on 0.0.0.0:3000 with anonymous Viewer
    # access enabled and no admin password. Re-add behind auth if a dashboard
    # is needed again.

    # Prometheus: reachable via trusted interfaces (LAN + tailscale) only
  };
}
