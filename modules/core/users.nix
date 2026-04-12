{ config, lib, pkgs, ... }:
{
  options.modules.users.enable = lib.mkEnableOption "default user (justin) and stateVersion" // { default = true; };

  config = lib.mkIf config.modules.users.enable {
    users.users.justin = {
      isNormalUser = true;
      initialHashedPassword = "$6$.4NRUvVflswGyxcb$pZJHgE2d/cY3N.WwZTm11NojG0YDotAfN4VeuLjeWaPsh3IgN/CyZhIjJJMrfITWT1Mk/Frl6RWSC8Ek/3o0C.";
      extraGroups = [ "wheel" "wireshark" "networkmanager" "lpadmin" ];
      packages = with pkgs; [
        tree
      ];
      shell = pkgs.nushell;
    };

    users.users.root.initialHashedPassword = "$6$.4NRUvVflswGyxcb$pZJHgE2d/cY3N.WwZTm11NojG0YDotAfN4VeuLjeWaPsh3IgN/CyZhIjJJMrfITWT1Mk/Frl6RWSC8Ek/3o0C.";

    system.stateVersion = "25.11";
  };
}
