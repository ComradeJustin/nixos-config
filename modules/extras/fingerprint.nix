{ config, lib, pkgs, ... }:
{
  options.modules.fingerprint.enable = lib.mkEnableOption "fingerprint reader support (Goodix 550A)";

  config = lib.mkIf config.modules.fingerprint.enable {
    environment.systemPackages = [ pkgs.fprintd ];

    services.fprintd.enable = true;
    services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix-550a;

    security.pam.services = {
      login.fprintAuth = true;
      sudo.fprintAuth = true;
      polkit-1.fprintAuth = true;
      quickshell-bar = {
        fprintAuth = true;
        # No timeout so fingerprint stays active indefinitely on lockscreen
        rules.auth.fprintd.args = [ "timeout=-1" "max-tries=-1" ];
      };
    };
  };
}
