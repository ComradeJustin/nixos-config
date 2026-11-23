# Login screen: greetd showing a greeter in the style of the desktop shell
# (configs/greeter), which starts niri. The greeter is QuickShell, full
# screen in cage; if it ever fails to start, the text greeter takes over.
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
    # The greeter's user has no home folder to keep these in.
    export XDG_CACHE_HOME="$XDG_RUNTIME_DIR/cache"
    export XDG_STATE_HOME="$XDG_RUNTIME_DIR/state"
    # cage shows the one window over the whole screen, and ends with the
    # greeter's own exit status: a failure hands over to the text greeter,
    # so that a mistake in the greeter never locks anyone out.
    ${lib.getExe pkgs.cage} -s -- ${lib.getExe quickshell} -p ${greeterConfig} || exec ${textGreeter}
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

  # The boot splash leaves its last picture on the screen when it quits,
  # until the greeter draws over it. Without this the screen is cleared to
  # a text console in between, which shows as a black flash.
  systemd.services.plymouth-quit.serviceConfig.ExecStart = [
    ""
    "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
  ];
}
