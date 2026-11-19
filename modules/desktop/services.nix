# Background services a desktop expects: printing, printer and device
# discovery, removable-drive mounting in file managers, and Flatpak.
{ pkgs, ... }:
{
  services.gvfs.enable = true;

  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    gutenprint
    hplip
  ];
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.flatpak.enable = true;
}
