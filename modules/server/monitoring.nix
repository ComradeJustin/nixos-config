{ config, lib, ... }:
{
  options.modules.monitoring.enable = lib.mkEnableOption "Prometheus + Grafana monitoring stack";

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

    # ── Grafana (dashboards) ──
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
          root_url = "%(protocol)s://%(domain)s:3000/";
        };
        security.secret_key = "$__file{/var/lib/grafana/secret_key}";
        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
      };
      provision = {
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:9090";
            isDefault = true;
          }
        ];
      };
    };

    # Grafana: reachable via trusted interfaces (LAN + tailscale) only
  };
}
