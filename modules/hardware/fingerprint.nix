{ config, lib, pkgs, ... }:
{
  options.modules.fingerprint.enable = lib.mkEnableOption "fingerprint reader support (Goodix 550A)";

  config = lib.mkIf config.modules.fingerprint.enable {
    environment.systemPackages = [ pkgs.fprintd ];

    services.fprintd.enable = true;
    services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix-550a;

    # Restart fprintd on failure so a stuck "claimed" state self-heals
    systemd.services.fprintd.serviceConfig = {
      Restart = "on-failure";
      RestartSec = 1;
    };

    # Kill fprintd before suspend, systemd D-Bus activation restarts it on next use
    systemd.services.fprintd-suspend-workaround = {
      description = "Stop fprintd before suspend to release device claim";
      before = [ "sleep.target" "suspend.target" "hibernate.target" ];
      wantedBy = [ "sleep.target" "suspend.target" "hibernate.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl stop fprintd.service";
      };
    };

    security.pam.services = {
      login.fprintAuth = true;
      sudo.fprintAuth = true;
      polkit-1.fprintAuth = true;
      quickshell-bar = {
        fprintAuth = true;
        rules.auth.fprintd.args = [ "timeout=-1" "max-tries=-1" ];
      };
    };
  };
}
