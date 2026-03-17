{ config, lib, pkgs, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-hard.yaml";
  stylix.polarity = "dark";

  stylix.cursor.package = pkgs.capitaine-cursors;
  stylix.cursor.name = "capitaine-cursors";
  stylix.cursor.size = 32;

  stylix.fonts = {
    serif = {
      package = pkgs.bodoni-moda;
      name = "Bodoni Moda Medium";
    };

    sansSerif = {
      package = pkgs.jost;
      name = "Jost* 600 Semi";
    };

    monospace = {
      package = pkgs.nerd-fonts.commit-mono;
      name = "CommitMono Nerd Font Mono";
    };

    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
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
