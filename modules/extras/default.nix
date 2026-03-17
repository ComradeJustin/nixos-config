# Optional feature modules with enable flags
# Import this file, then enable features per-host:
#   modules.gaming.enable = true;
#   modules.fingerprint.enable = true;
#   modules.compscijava.enable = true;
{
  imports = [
    ./gaming.nix
    ./fingerprint.nix
    ./compscijava.nix
    ./niri-system.nix
    ./quickshell.nix
    ./lockscreen.nix
  ];
}
