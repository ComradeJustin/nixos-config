# Home Manager profile for desktop machines. Imported by modules/desktop, so
# headless machines never get it.
#
# This file holds the settings that belong to the desktop as a whole. Each
# program with its own configuration has its own file beside it, and plain
# GUI apps are listed in apps.nix.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  # Config directories are linked straight to the repository checkout, so
  # editing them applies without a rebuild.
  repository = osConfig.programs.nh.flake;
  link = config.lib.file.mkOutOfStoreSymlink;

  # The Stylix scheme, for niri's palette file below.
  colours = config.lib.stylix.colors;
  # A colour channel, given as a number from 0 to 255 in text, at half its
  # value, as two hexadecimal digits.
  halved =
    channel: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString (lib.toInt channel / 2)));
in
{
  imports = [
    ./apps.nix
    ./ghostty.nix
    ./discord.nix
    ./spotify.nix
    ./music.nix
  ];

  home.sessionVariables = {
    BROWSER = "firefox";
    TERMINAL = "ghostty";
    NIXOS_OZONE_WL = "1";
  };

  xdg.configFile = {
    "niri" = {
      source = link "${repository}/configs/niri";
      recursive = true;
    };

    # niri's colours and cursor, from the Stylix theme, so that it follows
    # the same scheme as the desktop shell (configs/shell/Theme.qml names
    # what each colour is for). configs/niri/config.kdl includes this file;
    # the rest of niri's look is in configs/niri/layout.kdl.
    "niri-palette.kdl".text = ''
      // Written by Nix (home/desktop/default.nix). Do not edit.
      layout {
          border {
              active-color "#${colours.base0F}"
              inactive-color "#${colours.base03}"
              urgent-color "#${colours.base0A}"
          }
          // The background colour at half brightness, half see-through.
          shadow {
              color "#${halved colours.base00-rgb-r}${halved colours.base00-rgb-g}${halved colours.base00-rgb-b}80"
          }
          // Where a dragged window would land.
          insert-hint {
              color "#${colours.base0F}80"
          }
          tab-indicator {
              active-color "#${colours.base0F}"
              inactive-color "#${colours.base03}"
              urgent-color "#${colours.base0A}"
          }
      }
      recent-windows {
          highlight {
              active-color "#${colours.base0F}"
              urgent-color "#${colours.base0A}"
          }
      }
      // What shows behind everything until the wallpaper is up, which is
      // the first second after logging in: the same background colour the
      // login screen has.
      overview {
          backdrop-color "#${colours.base00}"
      }
      cursor {
          xcursor-theme "${osConfig.stylix.cursor.name}"
          xcursor-size ${toString osConfig.stylix.cursor.size}
      }
    '';
  };

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.gruvbox-plus-icons;
      name = "Gruvbox-Plus-Dark";
    };
  };

  services.gnome-keyring.enable = true;
}
