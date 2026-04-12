{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "usb_storage" "sd_mod" "sr_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];

  # Filesystem mounts handled by disko (disk-config.nix)

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
