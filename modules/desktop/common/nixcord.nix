{ config, lib, inputs, ... }:
{
  options.modules.nixcord.enable = lib.mkEnableOption "Nixcord (Discord via Vencord/Vesktop)";

  config = lib.mkIf config.modules.nixcord.enable {
    home-manager.sharedModules = [
      (
        { pkgs, ... }:
        {
          imports = [ inputs.nixcord.homeModules.nixcord ];
          programs.nixcord = {
            enable = true;
            discord.vencord.enable = true;
            vesktop.enable = true;
          };
        }
      )
    ];
  };
}
