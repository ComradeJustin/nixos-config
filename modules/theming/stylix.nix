{ config, lib, pkgs, ... }:
{
  stylix.enable = true;
  # autoEnable stays true (default) - we disable slow targets explicitly
  stylix.base16Scheme = ../../assets/colour-schemes/utilitarian.yaml;
  stylix.image = ../../assets/wallpapers/cloud.jpg;
  stylix.polarity = "dark";

  stylix.cursor.package = pkgs.capitaine-cursors;
  stylix.cursor.name = "capitaine-cursors";
  stylix.cursor.size = 32;

  # Utilitarian font stack - form follows function
  stylix.fonts = {
    serif = {
      package = pkgs.ibm-plex;
      name = "IBM Plex Serif";
    };

    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };

    monospace = {
      package = pkgs.jetbrains-mono;
      name = "JetBrains Mono";
    };

    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };

    sizes = {
      applications = 11;
      desktop = 11;
      popups = 11;
      terminal = 12;
    };
  };

  # Export Stylix colors as environment variables for QuickShell
  # QuickShell reads these via Quickshell.env("BASE00") etc.
  environment.sessionVariables = {
    BASE00 = "#${config.lib.stylix.colors.base00}";
    BASE01 = "#${config.lib.stylix.colors.base01}";
    BASE02 = "#${config.lib.stylix.colors.base02}";
    BASE03 = "#${config.lib.stylix.colors.base03}";
    BASE04 = "#${config.lib.stylix.colors.base04}";
    BASE05 = "#${config.lib.stylix.colors.base05}";
    BASE06 = "#${config.lib.stylix.colors.base06}";
    BASE07 = "#${config.lib.stylix.colors.base07}";
    BASE08 = "#${config.lib.stylix.colors.base08}";
    BASE09 = "#${config.lib.stylix.colors.base09}";
    BASE0A = "#${config.lib.stylix.colors.base0A}";
    BASE0B = "#${config.lib.stylix.colors.base0B}";
    BASE0C = "#${config.lib.stylix.colors.base0C}";
    BASE0D = "#${config.lib.stylix.colors.base0D}";
    BASE0E = "#${config.lib.stylix.colors.base0E}";
    BASE0F = "#${config.lib.stylix.colors.base0F}";
  };
}
