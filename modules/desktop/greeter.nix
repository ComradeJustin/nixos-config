# Login screen: greetd with tuigreet, which starts niri.
{ pkgs, ... }:
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
        # The theme names the console's colours, which Stylix sets from
        # the palette. It follows the desktop shell (configs/shell/Theme.qml):
        # borders in the dim line colour, what is typed in the brightest,
        # and salmon, the nearest the console has to the shell's accent,
        # for the prompt and the keys.
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session --theme 'border=darkgray;text=gray;time=gray;container=black;title=white;greet=gray;prompt=red;input=white;action=darkgray;button=red'";
        user = "greeter";
      };
    };
  };
  systemd.services.greetd.serviceConfig = {
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };
}
