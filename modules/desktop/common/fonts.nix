{ config, lib, pkgs, ... }:
{
  options.modules.fonts.enable = lib.mkEnableOption "font packages (Inter, IBM Plex, JetBrains Mono, Maple Mono, CJK, Nerd Fonts)";

  config = lib.mkIf config.modules.fonts.enable {
    fonts.packages = with pkgs; [
      inter
      ibm-plex
      jetbrains-mono
      maple-mono.NF
      fraunces          # display serif — QuickShell lock clock, Spotlight, headers
      hanken-grotesk    # UI / body sans — QuickShell panels

      noto-fonts-cjk-sans
      sarasa-gothic

      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.hack

      cozette
    ];
  };
}
