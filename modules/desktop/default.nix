# The graphical desktop: niri, the shell, audio, fonts, theme, and
# the desktop Home Manager profile.
# Importing this directory gives a machine the whole desktop.
{
  imports = [
    ./audio.nix
    ./boot-menu.nix
    ./fonts.nix
    ./greeter.nix
    ./splash.nix
    ./services.nix
    ./portals.nix
    ./theme.nix
    ./input-method.nix
    ./niri.nix
    ./notes.nix
    ./shell.nix
    ./programs.nix
  ];

  # Desktop machines also get home/desktop (GUI apps and their config).
  home-manager.users.justin.imports = [ ../../home/desktop ];
}
