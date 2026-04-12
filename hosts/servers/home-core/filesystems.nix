{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "usb_storage" "sd_mod" "sr_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5cfe1a14-211b-42ef-b730-64945baf2aec";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/674c30b9-161d-4e60-934e-b3546f2b97e4"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
