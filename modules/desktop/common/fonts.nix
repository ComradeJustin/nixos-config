{ config, inputs, lib, pkgs, ... }:
{
  options.modules.fonts.enable = lib.mkEnableOption "font packages (Inter, IBM Plex, JetBrains Mono, CJK, Nerd Fonts)";

  config = lib.mkIf config.modules.fonts.enable {
    fonts.packages = with pkgs; [
      inter
      ibm-plex
      jetbrains-mono

      noto-fonts-cjk-sans
      sarasa-gothic

      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.hack

      cozette
      inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd
    ];
  };
}
