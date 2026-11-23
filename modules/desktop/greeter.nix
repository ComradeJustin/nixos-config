# Login screen: greetd showing a greeter in the style of the desktop shell
# (configs/greeter), which starts niri. The greeter is QuickShell, in a niri
# of its own; if it ever fails to start, the text greeter takes over.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  colours = config.lib.stylix.colors;
  quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  shellFiles = ../../configs/shell;

  # The greeter's QML, with the pieces of the shell it is built from. It
  # runs from the Nix store: the greeter's user cannot read a home folder.
  greeterConfig = pkgs.runCommand "greeter-config" { } ''
    mkdir -p $out/shaders
    cp ${../../configs/greeter/shell.qml} $out/shell.qml
    cp ${shellFiles}/Theme.qml ${shellFiles}/Label.qml ${shellFiles}/Box.qml ${shellFiles}/DitherFade.qml $out/
    cp ${shellFiles}/shaders/dither-fade.frag.qsb $out/shaders/
  '';

  # The text greeter, for when the other cannot start. Its theme names the
  # console's colours, which Stylix sets from the palette.
  textGreeter = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session --theme 'border=darkgray;text=gray;time=gray;container=black;title=white;greet=gray;prompt=red;input=white;action=darkgray;button=red'";

  # The niri the greeter runs in: nothing but the theme's background, which
  # it paints from its first frame, so the screen is the same plain colour
  # the boot splash ends on until the greeter has drawn. When the greeter
  # ends, so does this niri; a mark is left if the greeter ended well.
  greeterNiri = pkgs.writeText "greeter-niri.kdl" ''
    // Written by modules/desktop/greeter.nix.
    // The screens' scale, as in the desktop's own niri.
    include "${../../configs/niri/screen.kdl}"
    prefer-no-csd
    hotkey-overlay {
        skip-at-startup
    }
    xwayland-satellite {
        off
    }
    cursor {
        hide-when-typing
        hide-after-inactive-ms 1000
    }
    animations {
        off
    }
    layout {
        background-color "#${colours.base00}"
    }
    // No key does anything here but type the password.
    binds {
    }
    spawn-at-startup "sh" "-c" "${lib.getExe quickshell} -p ${greeterConfig} && touch \"$XDG_RUNTIME_DIR/greeter-launched\"; ${lib.getExe pkgs.niri} msg action quit --skip-confirmation"
  '';

  # Building the system fails if niri would not accept that configuration.
  checkedGreeterNiri = pkgs.runCommand "greeter-niri-checked.kdl" { } ''
    ${lib.getExe pkgs.niri} validate --config ${greeterNiri}
    cp ${greeterNiri} $out
  '';

  greeter = pkgs.writeShellScript "greeter" ''
    # Who logs in, and what starts the session (configs/greeter/shell.qml).
    export GREETER_USER=justin
    export GREETER_HOST=${config.networking.hostName}
    export GREETER_SESSION=niri-session
    # The palette, as the shell's Theme.qml reads it.
    export BASE00='#${colours.base00}'
    export BASE03='#${colours.base03}'
    export BASE04='#${colours.base04}'
    export BASE05='#${colours.base05}'
    export BASE07='#${colours.base07}'
    export BASE0A='#${colours.base0A}'
    export BASE0F='#${colours.base0F}'
    # The greeter's user has no home folder. What it would keep there, such
    # as compiled QML and shaders, is kept here across boots, so that only
    # the first start is slow.
    export XDG_CACHE_HOME=/var/cache/greeter
    export XDG_STATE_HOME=/var/cache/greeter/state
    # If the greeter did not end well (it could not start, or it crashed),
    # hand over to the text greeter, so that a mistake in the greeter never
    # locks anyone out.
    rm -f "$XDG_RUNTIME_DIR/greeter-launched"
    ${lib.getExe pkgs.niri} --config ${checkedGreeterNiri}
    [ -e "$XDG_RUNTIME_DIR/greeter-launched" ] || exec ${textGreeter}
  '';
in
{
  services.xserver = {
    enable = true;
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${greeter}";
        user = "greeter";
      };
    };
  };
  systemd.services.greetd.serviceConfig = {
    # NixOS starts greetd as an "idle" service, which systemd holds back for
    # up to five seconds so that boot messages do not write over a text
    # greeter. The boot's text is hidden behind the splash, so the wait only
    # leaves the screen black after it.
    Type = lib.mkForce "simple";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  systemd.tmpfiles.rules = [ "d /var/cache/greeter 0700 greeter greeter -" ];

  # The boot splash is given a moment to finish wiping itself away before
  # it is told to quit (the wipe starts as this service does and takes a
  # little under a third of a second), and it leaves its last picture, the
  # plain background, on the screen when it goes.
  systemd.services.plymouth-quit.serviceConfig = {
    ExecStartPre = "${pkgs.coreutils}/bin/sleep 0.4";
    ExecStart = [
      ""
      "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
    ];
  };
}
