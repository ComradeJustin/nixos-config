# Tailscale on every machine. The tailnet is trusted by the firewall, so the
# tailnet's own access policy decides who can reach which port.
{ config, ... }:
{
  services.tailscale.enable = true;

  # Tailscale SSH: machines log in to each other through the tailnet, with no
  # keys to manage. Remote builds from nixlaptop to nixpc rely on it.
  services.tailscale.extraSetFlags = [ "--ssh" ];

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
