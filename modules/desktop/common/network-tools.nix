{ config, lib, pkgs, ... }:
{
  options.modules.network-tools.enable = lib.mkEnableOption "network diagnostic tools (dnsutils, traceroute, iperf3)";

  config = lib.mkIf config.modules.network-tools.enable {
    environment.systemPackages = with pkgs; [
      dnsutils
      traceroute
      iperf3
    ];
  };
}
