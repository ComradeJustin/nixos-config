# Tailscale on every machine. The tailnet is trusted by the firewall, so the
# tailnet's own access policy decides who can reach which port.
{ config, ... }:
{
  services.tailscale.enable = true;

  # Tailscale SSH: machines log in to each other through the tailnet, with no
  # keys to manage. Remote builds from nixlaptop to nixpc rely on it.
  services.tailscale.extraSetFlags = [ "--ssh" ];

  # The unit that applies those flags runs once and then counts as stopped,
  # and a rebuild only restarts units that are running: changed flags then
  # wait for the next boot. Counting it as running once it has finished
  # makes a rebuild apply them.
  systemd.services.tailscaled-set.serviceConfig.RemainAfterExit = true;

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
