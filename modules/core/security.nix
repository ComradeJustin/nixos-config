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
        PasswordAuthentication = true;
      };
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
      allowedUDPPorts = [ ];
    };

    services.fail2ban.enable = true;
  };
}
