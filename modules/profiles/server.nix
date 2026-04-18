{ config, lib, ... }:
{
  options.modules.profiles.server.enable = lib.mkEnableOption "server profile (sensible server defaults)";

  config = lib.mkIf config.modules.profiles.server.enable {
    modules.profiles.headless.enable = lib.mkDefault true;
    nix.settings.trusted-users = [ "root" "justin" ];

    # Disable desktop services that fail on headless systems
    home-manager.sharedModules = [{
      dconf.enable = lib.mkForce false;
      services.gnome-keyring.enable = lib.mkForce false;
    }];
  };
}
