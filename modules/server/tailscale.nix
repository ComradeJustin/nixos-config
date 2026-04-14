{ config, lib, pkgs, ... }:
let
  cfg = config.modules.tailscale;
in
{
  options.modules.tailscale = {
    enable = lib.mkEnableOption "Tailscale mesh VPN";
    exitNode = lib.mkEnableOption "advertise as Tailscale exit node";
    funnel = lib.mkEnableOption "expose a local port via Tailscale Funnel";
    funnelPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Local port to expose via Tailscale Funnel";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;

    environment.systemPackages = [ pkgs.tailscale ];

    # Allow Tailscale traffic through firewall
    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    # Exit node: enable IP forwarding and advertise
    boot.kernel.sysctl = lib.mkIf cfg.exitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
    services.tailscale.extraSetFlags = lib.mkIf cfg.exitNode [
      "--advertise-exit-node"
    ];

    # Funnel: serve a local port to the public internet
    systemd.services.tailscale-funnel = lib.mkIf cfg.funnel {
      description = "Tailscale Funnel";
      after = [ "tailscaled.service" "nginx.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.tailscale}/bin/tailscale funnel --bg ${toString cfg.funnelPort}";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
