# Discord through Vesktop, managed by nixcord. The official Discord client
# is not installed.
{ inputs, ... }:
{
  imports = [ inputs.nixcord.homeModules.nixcord ];

  programs.nixcord = {
    enable = true;
    discord.enable = false;
    vesktop.enable = true;
  };
}
