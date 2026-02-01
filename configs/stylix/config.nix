{ pkgs, ... }:
{
  stylix.enable = true;
  #stylix.image = ../../wallpapers/wallpaper.jpg;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/chicago-night.yaml";
  stylix.polarity = "dark";
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
