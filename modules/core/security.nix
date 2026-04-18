{ config, lib, ... }:
{
  options.modules.security.enable = lib.mkEnableOption "gnupg, openssh, firewall, fail2ban" // { default = true; };

  config = lib.mkIf config.modules.security.enable {
    programs.ssh.enableAskPassword = false;

    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      extraConfig = ''
        # Allow root key-only login from LAN for emergency recovery
        Match User root Address 192.168.1.0/24
            PermitRootLogin prohibit-password
      '';
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
      allowedUDPPorts = [ ];
    };

    services.fail2ban.enable = true;
  };
}
