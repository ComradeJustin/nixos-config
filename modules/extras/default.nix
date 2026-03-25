# Optional feature modules with enable flags
# Prefer enabling via a profile:
#   modules.profiles.desktop.enable = true;
# Or enable individually:
#   modules.gaming.enable = true;
#   modules.devtools.enable = true;
#   modules.media-cli.enable = true;
#   modules.network-tools.enable = true;
#   modules.ai.enable = true;
#   modules.creative.enable = true;
#   modules.spicetify.enable = true;
#   modules.nixcord.enable = true;
{
  imports = [
    ./gaming.nix
    ./fingerprint.nix
    ./compscijava.nix
    ./niri-system.nix
    ./quickshell.nix
    ./lockscreen.nix
    ./bluetooth.nix
    ./creative.nix
    ./devtools.nix
    ./media-cli.nix
    ./network-tools.nix
    ./ai.nix
    ../programs/spicetify.nix
    ../programs/nixcord.nix
  ];
}
