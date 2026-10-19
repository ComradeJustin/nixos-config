{ config, lib, pkgs, ... }:
{
  options.modules.users.enable = lib.mkEnableOption "default user (justin) and stateVersion" // { default = true; };

  config = lib.mkIf config.modules.users.enable {
    users.users.justin = {
      isNormalUser = true;
      # Only used when the user is first created (fresh install) — change it
      # with `passwd` on first login. Existing machines keep their password.
      initialPassword = "changeme";
      extraGroups = [ "wheel" "wireshark" "networkmanager" "lpadmin" "input" ];
      packages = with pkgs; [
        tree
      ];
      shell = pkgs.nushell;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHn/YMVvbeDt0NLp8tLhFc0cykp/Dq2huuhfUagVrIev chinese2000ping@gmail.com"
      ];
    };

    # Root has no password — use sudo, or the recovery key below over SSH.
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICiBr6+h5wioJw5BYXefcyX2w2Ytw3EfAayCeGsBaLQC root-recovery"
    ];

    # justin needs trusted-users for remote deploys and distributed builds
    nix.settings.trusted-users = [ "justin" ];

    system.stateVersion = "25.11";
  };
}
