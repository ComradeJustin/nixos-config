{ pkgs, ... }:
{
  stylix.enable = true;
  #stylix.image = ../../wallpapers/wallpaper.jpg;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-hard.yaml";
  stylix.polarity = "dark";

  stylix.cursor.package = pkgs.capitaine-cursors;
  stylix.cursor.name = "capitaine-cursors";
  stylix.cursor.size = 60;

  stylix.fonts = {

    serif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Serif";
    };

    sansSerif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans";
    };

    monospace = {
      package = pkgs.nerd-fonts.hurmit;
      name = "Hurmit Nerd Font Mono";
    };

    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };
  };
}

#{ pkgs, lib, ... }:
#let
#  inputImage = ../../wallpapers/wallpaper.jpg;
#  brightness = "-10";
#  contrast = "0";
#  fillColor = "black";
#in
#{
#
# stylix.enable = true;
#
# stylix.polarity = "dark";
#
#  stylix.image = pkgs.runCommand "dimmed-background.png" { } ''
#    ${lib.getExe' pkgs.imagemagick "convert"} "${inputImage}" -brightness-contrast ${brightness},${contrast} -fill ${fillColor} $out
#  '';
#}
