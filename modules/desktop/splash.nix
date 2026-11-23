# The boot splash: Plymouth with a theme in the style of the desktop shell.
# configs/splash/splash.script says what it shows; its pictures are drawn
# when the system is built, from the shell's font and the Stylix palette
# (configs/splash/make-images.py). While it is up, the boot's own text is
# hidden; Esc during the boot shows it again.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  colours = config.lib.stylix.colors;
  font = "${pkgs.nerd-fonts.departure-mono}/share/fonts/opentype/NerdFonts/DepartureMono/DepartureMonoNerdFontMono-Regular.otf";

  # The stages the splash lists, in the order the boot reaches them, and the
  # unit that marks each as reached when systemd names it.
  stages = [
    {
      name = "devices";
      unit = "systemd-udev-trigger.service";
    }
    {
      name = "disks";
      unit = "boot.mount";
    }
    {
      name = "network";
      unit = "NetworkManager.service";
    }
    {
      name = "login";
      unit = "systemd-user-sessions.service";
    }
  ];

  # The first part of the script: what this machine is, and the stages.
  settings = pkgs.writeText "settings.script" ''
    # Written by modules/desktop/splash.nix.
    HOSTNAME = "${config.networking.hostName}";
    FACTS = "nixos ${config.system.nixos.release} / linux ${config.boot.kernelPackages.kernel.version}";
    BACKGROUND_RED = ${colours.base00-dec-r};
    BACKGROUND_GREEN = ${colours.base00-dec-g};
    BACKGROUND_BLUE = ${colours.base00-dec-b};
    glyph_index = [];
    glyph_known = [];
    stage_name = [];
    stage_unit = [];
    ${lib.concatImapStrings (number: stage: ''
      stage_name[${toString (number - 1)}] = "${stage.name}";
      stage_unit[${toString (number - 1)}] = "${stage.unit}";
    '') stages}
    STAGE_COUNT = ${toString (builtins.length stages)};
  '';

  # The theme: the pictures, and the script put together from its three
  # parts (settings, where the glyphs are, and what to do).
  splash =
    pkgs.runCommand "shell-splash"
      {
        nativeBuildInputs = [ (pkgs.python3.withPackages (packages: [ packages.pillow ])) ];
      }
      ''
        theme=$out/share/plymouth/themes/shell-splash
        mkdir -p $theme
        python3 ${../../configs/splash/make-images.py} ${font} $theme \
          background=${colours.base00} field=${colours.base02} line=${colours.base03} \
          dim=${colours.base04} soft=${colours.base05} ink=${colours.base07} \
          accent=${colours.base0F} alert=${colours.base0A}
        cat ${settings} $theme/glyphs.script ${../../configs/splash/splash.script} > $theme/shell-splash.script
        rm $theme/glyphs.script
        cat > $theme/shell-splash.plymouth <<EOF
        [Plymouth Theme]
        Name=Shell splash
        Description=A panel of text over a dither field, in the style of the desktop shell
        ModuleName=script

        [script]
        ImageDir=$theme
        ScriptFile=$theme/shell-splash.script
        EOF
      '';
in
{
  boot.plymouth = {
    enable = true;
    theme = "shell-splash";
    themePackages = [ splash ];
  };
  # Stylix would otherwise set its own splash.
  stylix.targets.plymouth.enable = false;

  # Keep the boot's own text off the screen while the splash is up.
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "systemd.show_status=auto"
  ];
  boot.consoleLogLevel = 3;
}
