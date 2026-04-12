{ config, lib, pkgs, ... }:
{
  options.modules.tailscale = {
    enable = lib.mkEnableOption "Tailscale mesh VPN";
    exitNode = lib.mkEnableOption "advertise as Tailscale exit node";
  };

  config = lib.mkIf config.modules.tailscale.enable {
    services.tailscale.enable = true;

    environment.systemPackages = [ pkgs.tailscale ];

    # Allow Tailscale traffic through firewall
    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    # Exit node: enable IP forwarding and advertise
    boot.kernel.sysctl = lib.mkIf config.modules.tailscale.exitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
    services.tailscale.extraSetFlags = lib.mkIf config.modules.tailscale.exitNode [
      "--advertise-exit-node"
    ];
  };
}
