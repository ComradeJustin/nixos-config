{ config, lib, inputs, ... }:
{
  options.modules.nixcord.enable = lib.mkEnableOption "Nixcord";

  config = lib.mkIf config.modules.nixcord.enable {
    home-manager.sharedModules = [
      (
        { pkgs, ... }:
        {
          imports = [ inputs.nixcord.homeModules.nixcord ];
          programs.nixcord = {
            #discord.vencord.enable = true;
            vesktop.enable = true;
            enable = true;
          };
        }
      )
    ];
  };
}
