{ config, lib, ... }:
{
  options.modules.adguard.enable = lib.mkEnableOption "AdGuard Home DNS ad blocker";

  config = lib.mkIf config.modules.adguard.enable {
    services.adguardhome = {
      enable = true;
      openFirewall = false;  # reachable via trusted interfaces only
      mutableSettings = false;
      port = 3080;
      host = "0.0.0.0";
      settings = {
        http = {
          address = "0.0.0.0:3080";
        };
        dns = {
          bind_hosts = [ "0.0.0.0" ];
          port = 53;
          upstream_dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          bootstrap_dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };
        dhcp = {
          enabled = false;
        };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
        };
        filters = [
          { enabled = true; url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"; name = "AdGuard DNS filter"; id = 1; }
          { enabled = true; url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"; name = "AdAway Default Blocklist"; id = 2; }
        ];
      };
    };

    # DNS must be globally open for LAN clients
    networking.firewall.allowedUDPPorts = [ 53 ];
    # AdGuard UI: reachable via trusted interfaces only
  };
}
