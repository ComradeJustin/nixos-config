# The graphical desktop: niri, the shell widgets, audio, fonts, theme, and
# the desktop Home Manager profile.
# Importing this directory gives a machine the whole desktop.
{
  imports = [
    ./audio.nix
    ./fonts.nix
    ./greeter.nix
    ./services.nix
    ./portals.nix
    ./theme.nix
    ./input-method.nix
    ./niri.nix
    ./quickshell.nix
    ./ags.nix
    ./programs.nix
  ];

  # Desktop machines also get home/desktop.nix (GUI apps and their config).
  home-manager.users.justin.imports = [ ../../home/desktop.nix ];

  # btop's stock icon uses SVG features the Qt-based shell cannot render.
  nixpkgs.overlays = [ (import ../../overlays/btop-icon-fix.nix) ];
}
