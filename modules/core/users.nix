{ config, lib, pkgs, ... }:
{
  options.modules.users.enable = lib.mkEnableOption "default user (justin) and stateVersion" // { default = true; };

  config = lib.mkIf config.modules.users.enable {
    users.users.justin = {
      isNormalUser = true;
      extraGroups = [ "wheel" "wireshark" "networkmanager" "lpadmin" ];
      packages = with pkgs; [
        tree
      ];
      shell = pkgs.nushell;
    };

    system.stateVersion = "25.11";
  };
}
