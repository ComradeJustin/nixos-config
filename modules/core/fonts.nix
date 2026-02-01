{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    noto-fonts-cjk-sans
  ];
  # NerdFonts
  fonts.packages = with pkgs.nerd-fonts; [
    hurmit
    hack
    fira-code
  ];

}
