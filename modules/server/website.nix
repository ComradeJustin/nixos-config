# Public website on port 8443, also published by a Cloudflare Tunnel.
# The tunnel token is not in this repo. After creating the tunnel, install it on
# the host at /var/lib/cloudflared/token (mode 600). The dashboard hostname
# should point at http://localhost:8443.
{ config, lib, pkgs, ... }:
let
  cfg = config.modules.website;
  portfolio = ../../assets/portfolio;
  tokenFile = "/var/lib/cloudflared/token";
  tunnelScript = pkgs.writeShellScript "cloudflared-tunnel" ''
    set -eu
    exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file "$CREDENTIALS_DIRECTORY/token"
  '';
in
{
  options.modules.website.enable = lib.mkEnableOption "public website via Cloudflare Tunnel";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.cloudflared ];

    systemd.tmpfiles.rules = [
      "d /var/lib/cloudflared 0700 root root -"
    ];

    services.nginx = {
      enable = true;
      virtualHosts.portfolio = {
        listen = [{ addr = "0.0.0.0"; port = 8443; }];
        root = portfolio;
        # Missing pages get the site's own 404 page instead of nginx's default one.
        extraConfig = ''
          error_page 404 /404.html;
        '';
        locations."/" = {
          index = "index.html";
          # $uri.html lets /nowa-tan serve nowa-tan.html, so page links can leave off ".html".
          tryFiles = "$uri $uri.html $uri/ =404";
        };
      };
    };

    systemd.services.cloudflared-tunnel = {
      description = "Cloudflare Tunnel for the public website";
      after = [ "network-online.target" "nginx.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = tokenFile;
      serviceConfig = {
        ExecStart = tunnelScript;
        Restart = "on-failure";
        RestartSec = 5;
        DynamicUser = true;
        LoadCredential = "token:${tokenFile}";
      };
    };
  };
}
