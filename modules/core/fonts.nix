{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  fonts.packages = with pkgs; [
    # Utilitarian UI fonts
    inter                    # Primary sans-serif for UI
    ibm-plex                 # Industrial serif + mono family
    jetbrains-mono           # Technical monospace

    # CJK support
    noto-fonts-cjk-sans
    sarasa-gothic

    # Nerd Font variants (for icons)
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack

    # Additional
    cozette
    inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd
  ];
}
