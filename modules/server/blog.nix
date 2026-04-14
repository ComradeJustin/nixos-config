{ config, lib, pkgs, ... }:
let
  cfg = config.modules.blog;
  blogAdmin = ../../assets/blog-admin;
  blogCss = ../../assets/portfolio/blog.css;
  python = pkgs.python3;
in
{
  options.modules.blog = {
    enable = lib.mkEnableOption "self-hosted blog with admin panel";
    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      description = "Port for the internal blog admin panel";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.pandoc ];

    # Blog data directories
    systemd.tmpfiles.rules = [
      "d /var/lib/blog 0755 blog blog -"
      "d /var/lib/blog/posts 0755 blog blog -"
      "d /var/lib/blog/public 0755 blog blog -"
      "d /var/lib/blog/public/posts 0755 blog blog -"
    ];

    # Copy blog.css to public dir so published posts can reference it
    systemd.services.blog-css = {
      description = "Copy blog CSS to public dir";
      after = [ "systemd-tmpfiles-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/cp -f ${blogCss} /var/lib/blog/public/blog.css";
        User = "blog";
        Group = "blog";
      };
    };

    users.users.blog = {
      isSystemUser = true;
      group = "blog";
      home = "/var/lib/blog";
    };
    users.groups.blog = {};

    # Blog admin service
    systemd.services.blog-admin = {
      description = "Blog Admin Panel";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.pandoc ];
      serviceConfig = {
        ExecStart = "${python}/bin/python3 ${blogAdmin}/app.py";
        WorkingDirectory = "${blogAdmin}";
        User = "blog";
        Group = "blog";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Open admin port (internal network only — not exposed via Funnel)
    networking.firewall.allowedTCPPorts = [ cfg.adminPort ];
  };
}
