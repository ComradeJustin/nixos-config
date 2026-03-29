{ config, lib, pkgs, ... }:
let
  cfg = config.modules.testing;
in
{
  options.modules.testing = {
    enable = lib.mkEnableOption "testing overrides (experimental kernel, extra packages)";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to install for testing";
    };

    kernel = lib.mkOption {
      type = lib.types.nullOr lib.types.raw;
      default = null;
      description = "Override kernel (e.g. pkgs.linuxPackages_testing)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = cfg.packages;
    boot.kernelPackages = lib.mkIf (cfg.kernel != null) cfg.kernel;
  };
}
