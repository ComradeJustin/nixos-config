{ config, lib, ... }:
{
  options.modules.sops.enable = lib.mkEnableOption "sops-nix secrets management" // { default = true; };

  config = lib.mkIf config.modules.sops.enable {
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      secrets = {
        root_hashed_password = {
          neededForUsers = true;
        };
        justin_hashed_password = {
          neededForUsers = true;
        };
        smb_credentials = {
          mode = "0400";
        };
      };
    };

    # Public keys are not sensitive — safe to declare in plain text
    users.users.justin.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHn/YMVvbeDt0NLp8tLhFc0cykp/Dq2huuhfUagVrIev chinese2000ping@gmail.com"
    ];

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICiBr6+h5wioJw5BYXefcyX2w2Ytw3EfAayCeGsBaLQC root-recovery"
    ];

    users.users.root.hashedPasswordFile = config.sops.secrets.root_hashed_password.path;
    users.users.justin.hashedPasswordFile = config.sops.secrets.justin_hashed_password.path;
  };
}
