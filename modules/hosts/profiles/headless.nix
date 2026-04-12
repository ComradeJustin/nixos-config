{ config, lib, ... }:
{
  options.modules.hosts.headless.enable = lib.mkEnableOption "headless profile (no suspend, serial console, no GUI)";

  config = lib.mkIf config.modules.hosts.headless.enable {
    systemd.targets.sleep.enable = false;
    systemd.targets.suspend.enable = false;
    systemd.targets.hibernate.enable = false;
    systemd.targets.hybrid-sleep.enable = false;

    # Ignore lid close — server laptops run with lid closed
    services.logind.settings.Login.HandleLidSwitch = "ignore";
    services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
    services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

    boot.kernelParams = [ "console=ttyS0,115200n8" ];
  };
}
