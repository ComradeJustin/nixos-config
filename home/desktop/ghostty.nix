# Ghostty terminal.
{ config, lib, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      quit-after-last-window-closed = false;

      # Cozette, a pixel font, in place of the monospace font that Stylix
      # gives the terminal. It is a bitmap: drawn at one size, 13 pixels
      # high (a twice-as-large version exists too). Ghostty counts in
      # points, and 9.75 points is 13 pixels. Several files of the font
      # share the name "Cozette"; the style picks the 13-pixel one.
      # It has no bold or italic of its own, so those look like plain text.
      font-family = lib.mkForce [
        "Cozette"
        config.stylix.fonts.emoji.name
      ];
      font-style = "Medium";
      font-size = lib.mkForce 9.75;
      freetype-load-flags = "monochrome";
    };
  };
}
