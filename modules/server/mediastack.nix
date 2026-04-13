{ config, lib, pkgs, ... }:
let
  cfg = config.modules.mediastack;
  mediaDir = "/srv/media";
in
{
  options.modules.mediastack = {
    enable = lib.mkEnableOption "Jellyfin + arr stack (Radarr, Sonarr, Prowlarr, qBittorrent)";
  };

  config = lib.mkIf cfg.enable {
    # Media directories
    systemd.tmpfiles.rules = [
      "d ${mediaDir}            0775 jellyfin media -"
      "d ${mediaDir}/movies     0775 jellyfin media -"
      "d ${mediaDir}/tv         0775 jellyfin media -"
      "d ${mediaDir}/downloads  0775 qbittorrent media -"
    ];

    users.groups.media = {};

    # ── Jellyfin ──
    services.jellyfin = {
      enable = true;
      openFirewall = true;  # port 8096
    };
    users.users.jellyfin.extraGroups = [ "media" ];

    # ── qBittorrent ──
    services.qbittorrent = {
      enable = true;
      #port = 8080;
      openFirewall = true;

    };
    users.users.qbittorrent.extraGroups = [ "media" ];

    # ── Radarr (movies) ──
    services.radarr = {
      enable = true;
      openFirewall = true;  # port 7878
    };
    users.users.radarr.extraGroups = [ "media" ];

    # ── Sonarr (TV) ──
    services.sonarr = {
      enable = true;
      openFirewall = true;  # port 8989
    };
    users.users.sonarr.extraGroups = [ "media" ];

    # ── Prowlarr (indexers) ──
    services.prowlarr = {
      enable = true;
      openFirewall = true;  # port 9696
    };

    # Radarr, Sonarr, and Prowlarr need URL base set for subpath proxying
    # Configure via their web UIs: Settings > General > URL Base
    # Radarr: /radarr  Sonarr: /sonarr  Prowlarr: /prowlarr
  };
}
