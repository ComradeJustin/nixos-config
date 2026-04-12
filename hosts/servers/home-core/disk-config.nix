{
  disko.devices = {
    disk.main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02";  # BIOS boot partition for GRUB MBR
          };
          root = {
            end = "-4G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
          swap = {
            size = "4G";
            content = {
              type = "swap";
            };
          };
        };
      };
    };
  };
}
