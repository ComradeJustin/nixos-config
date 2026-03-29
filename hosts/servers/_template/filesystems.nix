# Template: extract from hardware-configuration.nix after running nixos-generate-config
# Keep only fileSystems, swapDevices, and boot.initrd.* entries here.
# Hardware detection (kernel modules, drivers, microcode) is handled by facter.json.
{ ... }:
{
  # boot.initrd.availableKernelModules = [ ... ];
  # boot.initrd.kernelModules = [ ... ];

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/XXXX";
  #   fsType = "ext4";
  # };

  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-uuid/XXXX";
  #   fsType = "vfat";
  # };

  # swapDevices = [
  #   { device = "/dev/disk/by-uuid/XXXX"; }
  # ];
}
