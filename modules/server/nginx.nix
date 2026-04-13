{ config, lib, ... }:
let
  hostname = config.networking.hostName;
in
{
  options.modules.nginx.enable = lib.mkEnableOption "Nginx reverse proxy";

  config = lib.mkIf config.modules.nginx.enable {
    # ── Homepage Dashboard ──
    services.homepage-dashboard = {
      enable = true;
      listenPort = 8082;
      allowedHosts = "${hostname},${hostname}:80,localhost:8082,127.0.0.1:8082";
      environmentFiles = [ "/var/lib/homepage-dashboard/env" ];

      settings = {
        title = hostname;
        background = {
          image = "";
          blur = "sm";
          opacity = 50;
        };
        theme = "dark";
        color = "stone";
        headerStyle = "clean";
        layout = {
          Media = { style = "row"; columns = 2; };
          Downloads = { style = "row"; columns = 3; };
          Infrastructure = { style = "row"; columns = 3; };
        };
      };

      widgets = [
        { resources = { cpu = true; memory = true; disk = "/"; }; }
        { search = { provider = "duckduckgo"; target = "_blank"; }; }
      ];

      services = [
        {
          Media = [
            {
              Jellyfin = {
                icon = "jellyfin.svg";
                href = "http://${hostname}:8096";
                description = "Media Server";
                widget = {
                  type = "jellyfin";
                  url = "http://127.0.0.1:8096";
                  enableBlocks = true;
                };
              };
            }
          ];
        }
        {
          Downloads = [
            {
              Radarr = {
                icon = "radarr.svg";
                href = "http://${hostname}:7878";
                description = "Movies";
                widget = {
                  type = "radarr";
                  url = "http://127.0.0.1:7878";
                  key = "{{HOMEPAGE_VAR_RADARR_KEY}}";
                };
              };
            }
            {
              Sonarr = {
                icon = "sonarr.svg";
                href = "http://${hostname}:8989";
                description = "TV Shows";
                widget = {
                  type = "sonarr";
                  url = "http://127.0.0.1:8989";
                  key = "{{HOMEPAGE_VAR_SONARR_KEY}}";
                };
              };
            }
            {
              qBittorrent = {
                icon = "qbittorrent.svg";
                href = "http://${hostname}:8080";
                description = "Torrent Client";
                widget = {
                  type = "qbittorrent";
                  url = "http://127.0.0.1:8080";
                  username = "admin";
                  password = "{{HOMEPAGE_VAR_QBIT_PASS}}";
                };
              };
            }
          ];
        }
        {
          Infrastructure = [
            {
              Grafana = {
                icon = "grafana.svg";
                href = "http://${hostname}:3000";
                description = "Monitoring";
              };
            }
            {
              Prowlarr = {
                icon = "prowlarr.svg";
                href = "http://${hostname}:9696";
                description = "Indexer Manager";
                widget = {
                  type = "prowlarr";
                  url = "http://127.0.0.1:9696";
                  key = "{{HOMEPAGE_VAR_PROWLARR_KEY}}";
                };
              };
            }
            {
              Harmonia = {
                icon = "mdi-package-variant-closed";
                href = "http://${hostname}:5000/nix-cache-info";
                description = "Nix Binary Cache";
              };
            }
          ];
        }
      ];
    };

    # ── Nginx ──
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;

      virtualHosts.default = {
        default = true;
        locations."/".proxyPass = "http://127.0.0.1:8082";
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
