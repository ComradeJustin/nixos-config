{ config, lib, ... }:
{
  options.modules.locale.enable = lib.mkEnableOption "timezone and i18n locale" // { default = true; };

  config = lib.mkIf config.modules.locale.enable {
    time.timeZone = "America/Vancouver";
    i18n.defaultLocale = "en_US.UTF-8";
  };
}
