{ config, lib, ... }:
{
  options.modules.profiles.desktop.enable = lib.mkEnableOption "desktop profile (Niri, QuickShell, dev tools, media, AI)";

  config = lib.mkIf config.modules.profiles.desktop.enable {
    modules.niri.enable = true;
    modules.quickshell.enable = true;
    modules.lockscreen.enable = true;
    modules.compscijava.enable = true;
    modules.creative.enable = true;
    modules.spicetify.enable = true;
    modules.nixcord.enable = true;
    modules.devtools.enable = true;
    modules.media-cli.enable = true;
    modules.network-tools.enable = true;
    modules.ai.enable = true;
  };
}
