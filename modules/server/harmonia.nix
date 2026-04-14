{ config, lib, ... }:
{
  options.modules.harmonia.enable = lib.mkEnableOption "Harmonia binary cache server";

  config = lib.mkIf config.modules.harmonia.enable {
    services.harmonia.cache = {
      enable = true;
      signKeyPaths = [ "/var/lib/harmonia/cache-key.pem" ];
      settings.bind = "[::]:5000";
    };

    # Generate signing key on first boot if it doesn't exist
    systemd.services.harmonia-keygen = {
      description = "Generate Harmonia signing key";
      wantedBy = [ "harmonia.service" ];
      before = [ "harmonia.service" ];
      unitConfig.ConditionPathExists = "!/var/lib/harmonia/cache-key.pem";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ config.nix.package ];
      script = ''
        mkdir -p /var/lib/harmonia
        nix-store --generate-binary-cache-key ${config.networking.hostName} \
          /var/lib/harmonia/cache-key.pem \
          /var/lib/harmonia/cache-key.pub
      '';
    };

    # Harmonia: reachable via trusted interfaces only
  };
}
