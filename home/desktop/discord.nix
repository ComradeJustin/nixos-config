# Discord through Vesktop, managed by nixcord.
{ inputs, ... }:
{
  imports = [ inputs.nixcord.homeModules.nixcord ];

  programs.nixcord = {
    enable = true;
    vesktop.enable = true;
  };
}
