# AdGuard Home: DNS ad blocking for the LAN and the tailnet. The host opens
# port 53 on its LAN interface (see hosts/nixpc/default.nix).
{ ... }:
{
  services.adguardhome = {
    enable = true;
    openFirewall = false;
    mutableSettings = false;
    settings = {
      # The admin page has no login, so it listens on this machine only.
      # To open it: ssh -L 3080:127.0.0.1:3080 nixpc, then http://localhost:3080
      http = {
        address = "127.0.0.1:3080";
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
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard DNS filter";
          id = 1;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
          name = "AdAway Default Blocklist";
          id = 2;
        }
      ];
    };
  };
}
