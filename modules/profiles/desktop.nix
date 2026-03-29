{ config, lib, ... }:
{
  options.modules.profiles.desktop = {
    enable = lib.mkEnableOption "desktop profile (Niri, dev tools, media, creative)";

    wm = lib.mkOption {
      type = lib.types.str;
      default = "niri";
      description = "Window manager to use (currently only 'niri' supported)";
    };
  };

  config = lib.mkIf config.modules.profiles.desktop.enable {
    # Desktop infrastructure
    modules.fonts.enable = lib.mkDefault true;
    modules.greetd.enable = lib.mkDefault true;
    modules.gui-packages.enable = lib.mkDefault true;
    modules.portals.enable = lib.mkDefault true;
    modules.theming.enable = lib.mkDefault true;

    # WM-conditional
    modules.niri.enable = lib.mkDefault (config.modules.profiles.desktop.wm == "niri");
    modules.quickshell.enable = lib.mkDefault (config.modules.profiles.desktop.wm == "niri");
    modules.lockscreen.enable = lib.mkDefault (config.modules.profiles.desktop.wm == "niri");

    # Common desktop apps
    modules.creative.enable = lib.mkDefault true;
    modules.spicetify.enable = lib.mkDefault true;
    modules.nixcord.enable = lib.mkDefault true;
    modules.devtools.enable = lib.mkDefault true;
    modules.media-cli.enable = lib.mkDefault true;
    modules.network-tools.enable = lib.mkDefault true;
  };
}
