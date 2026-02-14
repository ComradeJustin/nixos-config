{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    nerd-fonts.hurmit
    nerd-fonts.hack
    nerd-fonts.fira-code
    noto-fonts
    nerd-fonts.symbols-only
    noto-fonts-cjk-serif
    liberation_ttf
    dejavu_fonts
    fira-code
    mplus-outline-fonts
  ];

}
