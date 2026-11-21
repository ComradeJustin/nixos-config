# Background services a desktop expects: printing, device discovery,
# removable-drive mounting in file managers, and Flatpak.
{ pkgs, ... }:
{
  services.gvfs.enable = true;

  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    gutenprint
    hplip
  ];
  # Do not add printers automatically just because a network advertises them.
  # Printers are added by hand (CUPS at http://localhost:631).
  services.printing.browsed.enable = false;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # NixOS turns the speech synthesiser on for every graphical system, and it
  # brings 645 MiB of voices with it. Nothing here uses text-to-speech.
  services.speechd.enable = false;

  services.flatpak.enable = true;
}
