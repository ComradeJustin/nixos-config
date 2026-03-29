# TODO: Generate on home-core with nixos-generate-config, then replace
# the placeholder values with real UUIDs from the machine.
# Hardware detection (kernel modules, drivers) will be handled by facter.json.
{ ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";

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
