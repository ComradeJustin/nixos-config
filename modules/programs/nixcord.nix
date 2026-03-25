{ config, lib, inputs, ... }:
{
  options.modules.nixcord.enable = lib.mkEnableOption "Nixcord (Discord via Vencord/Vesktop)";

  config = lib.mkIf config.modules.nixcord.enable {
    home-manager.sharedModules = [
      (
        { pkgs, ... }:
        {
          # import the flake's module for your system
          imports = [ inputs.nixcord.homeModules.nixcord ];
          programs.nixcord = {
            enable = true;

            # Choose your client (enable only one of these two)
            discord.vencord.enable = true; # Standard Vencord
            # discord.equicord.enable = true;   # Equicord (has more plugins)

            # Or these
            vesktop.enable = true;
            # dorion.enable = true;

            # Theming - Vencord uses CSS theming
            # Stylix can generate themes via stylix.targets.vesktop.enable = true

          };
        }
      )
    ];
  };
}
