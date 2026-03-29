{ config, lib, pkgs, ... }:
let
  cfg = config.modules.boot;
in
{
  options.modules.boot = {
    enable = lib.mkEnableOption "boot loader, latest kernel, fstrim, fwupd" // { default = true; };

    loader = lib.mkOption {
      type = lib.types.enum [ "limine" "grub-efi" "grub-mbr" ];
      default = "limine";
      description = ''
        Boot loader to use:
        - limine: Limine UEFI boot (default for desktops)
        - grub-efi: GRUB2 with EFI
        - grub-mbr: GRUB2 with MBR/BIOS (for legacy systems)
      '';
    };

    grubDevice = lib.mkOption {
      type = lib.types.str;
      default = "nodev";
      description = "Device to install GRUB to (e.g. /dev/sda). Only used with grub-mbr.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader = lib.mkMerge [
      (lib.mkIf (cfg.loader == "limine") {
        limine.enable = true;
        efi.canTouchEfiVariables = true;
      })
      (lib.mkIf (cfg.loader == "grub-efi") {
        grub.enable = true;
        grub.efiSupport = true;
        grub.device = "nodev";
        efi.canTouchEfiVariables = true;
      })
      (lib.mkIf (cfg.loader == "grub-mbr") {
        grub.enable = true;
        grub.device = cfg.grubDevice;
      })
    ];

    boot.kernelPackages = pkgs.linuxPackages_latest;

    services.fstrim.enable = true;
    services.fwupd.enable = true;
  };
}
