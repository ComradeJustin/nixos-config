# Extra (non-generated) mounts for nixpc.
# Kept out of hardware-configuration.nix, which is auto-generated.
{ ... }:
{
  # 1.8 TB Seagate ST2000DM008 data drive (sdb1)
  fileSystems."/mnt/dumps" = {
    device = "/dev/disk/by-uuid/e36f250a-af82-4790-a8bf-2490426a1a86";
    fsType = "ext4";
    # x-gvfs-show makes it appear in the Nautilus sidebar; x-gvfs-name sets the label.
    options = [ "noatime" "nofail" "x-gvfs-show" "x-gvfs-name=Dumps" ];
  };
}
