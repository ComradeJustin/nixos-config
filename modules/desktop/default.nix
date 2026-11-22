# The graphical desktop: niri, the shell, audio, fonts, theme, and
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
    ./shell.nix
    ./programs.nix
  ];

  # Desktop machines also get home/desktop (GUI apps and their config).
  home-manager.users.justin.imports = [ ../../home/desktop ];
}
