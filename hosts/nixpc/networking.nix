{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.hostName = "nixpc";

  # Wake-on-LAN: enable on the primary ethernet interface
  # Find interface name with: ip link show
  networking.interfaces.enp4s0.wakeOnLan.enable = true;
}
