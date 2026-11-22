# The desktop shell: the bar, notifications, the lock screen, the ring and
# the monitor. It is QuickShell running the QML in configs/shell, straight
# from the repository checkout, so an edit applies on a restart of the
# service, without a rebuild:  systemctl --user restart shell
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  shellDirectory = "${config.programs.nh.flake}/configs/shell";
in
{
  # What the shell runs. It also uses niri, wl-clipboard, cliphist, awww,
  # brightnessctl and swayidle (niri.nix), and its font (fonts.nix).
  environment.systemPackages = [
    quickshell
    pkgs.wlsunset # night light
    pkgs.libnotify # notify-send: battery and Tailscale warnings
    pkgs.inotify-tools # inotifywait: the camera flag
  ];

  # Supervised, because the lock screen lives in the shell: a locked session
  # whose lock screen has gone shows nothing to unlock it with.
  systemd.user.services.shell = {
    description = "Desktop shell";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    # NixOS pins each unit's PATH to a minimal set; the shell runs session
    # tools (niri, awww, loginctl, tailscale), so give it the system and
    # per-user profiles too.
    path = [
      "/run/current-system/sw"
      "/etc/profiles/per-user/justin"
    ];
    serviceConfig = {
      ExecStart = "${lib.getExe quickshell} -p ${shellDirectory}";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # The battery, for the bar and the low-battery warnings.
  services.upower.enable = true;

  # The shell's Network page turns Tailscale and its exit nodes on and off,
  # which only root may do unless the user is named as the operator.
  services.tailscale.extraSetFlags = [ "--operator=justin" ];

  # The lock screen's fingerprint check goes through this PAM service.
  # hosts/nixlaptop/fingerprint.nix adds the fingerprint reader to it.
  security.pam.services.quickshell-bar = { };
}
