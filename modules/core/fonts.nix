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
  ];


}
