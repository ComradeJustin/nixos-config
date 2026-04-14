{ lib, ... }:
{
  networking.hostName = "home-core";

  # Static IP — DHCP was causing network drops
  networking.interfaces.enp9s0 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.1.244";
      prefixLength = 24;
    }];
  };
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # Disable WiFi — not needed on a wired server
  networking.wireless.enable = lib.mkForce false;
}
