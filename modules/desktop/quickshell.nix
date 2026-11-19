# QuickShell status bar, widgets and lock screen. Its QML config lives in
# configs/quickshell and is linked into place by home/desktop/default.nix.
{ inputs, pkgs, ... }:
{
  # Also used by the shell: wl-clipboard, cliphist, brightnessctl and
  # playerctl (niri.nix), and curl and jq (base.nix).
  environment.systemPackages = with pkgs; [
    glib
    inputs.qml-niri.packages.${pkgs.stdenv.hostPlatform.system}.quickshell
    qt5.qtgraphicaleffects
    kdePackages.qt5compat
    inotify-tools
    imagemagick
    cava # media visualizer
    wlsunset # night light
  ];

  services.upower.enable = true;

  # PAM service for lock screen authentication.
  # hosts/nixlaptop/fingerprint.nix adds fingerprint unlock to it.
  security.pam.services.quickshell-bar = { };
}
