# Ghostty terminal.
{ config, lib, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      quit-after-last-window-closed = false;

      # The desktop shell's pixel font, in place of the monospace font that
      # Stylix gives the terminal. It is only sharp at 11 pixels and whole
      # multiples of that; Ghostty counts in points, and 8.25 points is 11
      # pixels. Drawn without smoothing, every pixel of it is on or off.
      font-family = lib.mkForce [
        "DepartureMono Nerd Font"
        config.stylix.fonts.emoji.name
      ];
      font-size = lib.mkForce 8.25;
      freetype-load-flags = "monochrome";
    };
  };
}
