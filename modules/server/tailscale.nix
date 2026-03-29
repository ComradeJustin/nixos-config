{ config, lib, pkgs, ... }:
{
  options.modules.tailscale.enable = lib.mkEnableOption "Tailscale mesh VPN";

  config = lib.mkIf config.modules.tailscale.enable {
    services.tailscale.enable = true;

    environment.systemPackages = [ pkgs.tailscale ];

    # Allow Tailscale traffic through firewall
    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };
  };
}
