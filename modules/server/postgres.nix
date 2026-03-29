{ config, lib, pkgs, ... }:
{
  options.modules.postgres.enable = lib.mkEnableOption "PostgreSQL database server";

  config = lib.mkIf config.modules.postgres.enable {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
    };
  };
}
