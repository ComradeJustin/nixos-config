# Template: set hostname and any static IP / interface config
{ ... }:
{
  networking.hostName = "CHANGEME";

  # Static IP example:
  # networking.interfaces.eth0.ipv4.addresses = [{
  #   address = "192.168.1.100";
  #   prefixLength = 24;
  # }];
  # networking.defaultGateway = "192.168.1.1";
  # networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
}
