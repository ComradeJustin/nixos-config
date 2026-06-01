{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.gaming.enable = lib.mkEnableOption "gaming packages (Steam, Prismlauncher, Gamescope, Wine)";

  config = lib.mkIf config.modules.gaming.enable {
    programs.steam.enable = true;

    environment.systemPackages = with pkgs; [
      prismlauncher
      gamescope
      wineWow64Packages.stableFull
      rimsort
    ];
  };
}
