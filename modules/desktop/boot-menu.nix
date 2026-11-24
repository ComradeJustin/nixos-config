# The boot menu (Limine, where a system or an older generation is picked) in
# the style of the desktop shell. Limine draws the menu as plain text over a
# picture: the text gets the shell's font and palette, and the picture draws
# the shell's panel around it. Both are made when the system is built
# (configs/boot-menu/make-images.py).
{
  config,
  pkgs,
  ...
}:
let
  colours = config.lib.stylix.colors;
  font = "${pkgs.nerd-fonts.departure-mono}/share/fonts/opentype/NerdFonts/DepartureMono/DepartureMonoNerdFontMono-Regular.otf";

  # The picture is drawn for one screen: the laptop's. On a screen of
  # another size it is centred, and the panel no longer fits the text.
  screenWidth = 1920;
  screenHeight = 1080;
  # The space Limine leaves around its text, in pixels, on every side. What
  # is left of the screen's height is 24 rows of text: the panel's height.
  margin = 372;

  images =
    pkgs.runCommand "boot-menu-images"
      {
        nativeBuildInputs = [ (pkgs.python3.withPackages (packages: [ packages.pillow ])) ];
      }
      ''
        python3 ${../../configs/boot-menu/make-images.py} ${font} $out ${config.networking.hostName} \
          ${toString screenWidth} ${toString screenHeight} ${toString margin} \
          background=${colours.base00} line=${colours.base03} dim=${colours.base04} ink=${colours.base07}
      '';
in
{
  # Stylix would only set the menu's colours; everything is set here.
  stylix.targets.limine.enable = false;

  boot.loader.limine = {
    # NixOS has no option for the font. The file has to be on the boot
    # partition, where Limine can read it.
    additionalFiles."limine/font.bin" = "${images}/font.bin";
    extraConfig = ''
      term_font: boot():/limine/font.bin
      term_font_size: 8x14
    '';

    style = {
      wallpapers = [ "${images}/wallpaper.png" ];
      wallpaperStyle = "centered";
      backdrop = colours.base00;

      interface = {
        resolution = "${toString screenWidth}x${toString screenHeight}";
        # Limine's own title and its list of keys are left out: the picture
        # has the hostname and the keys, in the shell's words.
        branding = "";
        helpHidden = true;
        # The countdown is written in these two: the words, and the number.
        helpColor = colours.base04;
        helpColorBright = colours.base0F;
      };

      graphicalTerminal = {
        font = {
          scale = "1x1";
          spacing = 0;
        };
        inherit margin;
        marginGradient = 0;
        # The first two digits make the text's own background fully
        # see-through, so the picture shows behind it.
        background = "ff${colours.base00}";
        foreground = colours.base05;
        brightBackground = colours.base03;
        brightForeground = colours.base07;
        # Black, red, green, brown, blue, magenta, cyan, gray. Cyan is the
        # shell's dim text colour: Limine writes the note about the chosen
        # system in cyan.
        palette =
          with colours;
          "${base00};${base08};${base0B};${base0A};${base0D};${base0E};${base04};${base05}";
        brightPalette =
          with colours;
          "${base03};${base08};${base0B};${base0A};${base0D};${base0E};${base04};${base07}";
      };
    };
  };
}
