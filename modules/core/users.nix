{ config, lib, pkgs, ... }:
{
  options.modules.users.enable = lib.mkEnableOption "default user (justin) and stateVersion" // { default = true; };

  config = lib.mkIf config.modules.users.enable {
    users.users.justin = {
      isNormalUser = true;
      # Password is provided by sops-nix as hashedPasswordFile (see modules/core/sops.nix).
      extraGroups = [ "wheel" "wireshark" "networkmanager" "lpadmin" "input" ];
      packages = with pkgs; [
        tree
      ];
      shell = pkgs.nushell;
    };

    # Root password managed by sops-nix (modules/core/sops.nix)

    # justin needs trusted-users for remote deploys and distributed builds
    nix.settings.trusted-users = [ "justin" ];

    system.stateVersion = "25.11";
  };
}
