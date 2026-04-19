{ config, lib, pkgs, ... }:
let
  cfg = config.modules.samba;
in
{
  options.modules.samba = {
    enable = lib.mkEnableOption "Samba file server";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv";
      description = "Root directory for the shared share";
    };

    homeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/samba";
      description = "Root directory for per-user personal folders";
    };

    admins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "justin" ];
      description = "Users with read/write access to all shares";
    };

    sambaUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Samba-only users (no shell, no login — only SMB access). Each gets a personal folder.";
    };
  };

  config = lib.mkIf cfg.enable {
    # All samba participants need the samba group
    users.groups.samba = { };

    # Samba-only users: no shell, no login, no sudo — exist purely for SMB auth
    # Admin users: add samba group
    users.users = lib.mkMerge [
      (lib.listToAttrs (map (name: {
        inherit name;
        value = {
          isSystemUser = true;
          group = "samba";
          shell = "/run/current-system/sw/bin/nologin";
          home = "/var/empty";
          createHome = false;
        };
      }) cfg.sambaUsers))
      (lib.listToAttrs (map (name: {
        inherit name;
        value = { extraGroups = [ "samba" ]; };
      }) cfg.admins))
    ];

    services.samba = {
      enable = true;
      openFirewall = false; # Accessible via Tailscale trusted interfaces only

      settings = let
        allUsers = cfg.admins ++ cfg.sambaUsers;
        adminStr = lib.concatStringsSep " " cfg.admins;
        allUsersStr = lib.concatStringsSep " " allUsers;

        # Shared folder — points to dataDir root, everyone rw via samba group
        sharedShare = {
          shared = {
            path = cfg.dataDir;
            "read only" = "no";
            browseable = "yes";
            "valid users" = allUsersStr;
            "force group" = "samba";
            "create mask" = "0664";
            "directory mask" = "2775";
            "inherit permissions" = "yes";
          };
        };

        # Per-user folders — owner + admins can access via samba group
        userShares = lib.listToAttrs (map (name: {
          inherit name;
          value = {
            path = "${cfg.homeDir}/${name}";
            "read only" = "no";
            browseable = "yes";
            "valid users" = "${name} ${adminStr}";
            "force group" = "samba";
            "create mask" = "0660";
            "directory mask" = "2770";
            "inherit permissions" = "yes";
          };
        }) allUsers);

      in {
        global = {
          "server string" = config.networking.hostName;
          "server role" = "standalone server";

          # Security
          "map to guest" = "never";
          "usershare allow guests" = false;

          # iOS compatibility
          "server min protocol" = "SMB2";
          "ea support" = "yes";
          "vfs objects" = "fruit streams_xattr";
          "fruit:metadata" = "stream";
          "fruit:model" = "MacSamba";

          # Performance
          "use sendfile" = true;
          "min receivefile size" = 16384;
          "aio read size" = 16384;
          "aio write size" = 16384;

          # Limit to LAN and Tailscale
          "hosts allow" = "192.168.1.0/24 100.64.0.0/10 127.0.0.1";
          "hosts deny" = "0.0.0.0/0";
        };
      } // sharedShare // userShares;
    };

    # Create share directories with correct ownership
    systemd.tmpfiles.rules =
      let
        allUsers = cfg.admins ++ cfg.sambaUsers;
      in
      # Shared directory — setgid so new dirs inherit samba group
      [ "d ${cfg.dataDir} 2775 ${builtins.head cfg.admins} samba -" ]
      # Home directory root
      ++ [ "d ${cfg.homeDir} 0755 root samba -" ]
      # Per-user folders — setgid, owned by user, group samba
      ++ map (name: "d ${cfg.homeDir}/${name} 2770 ${name} samba -") allUsers;

    # Enable wsdd for Windows network discovery
    services.samba-wsdd = {
      enable = true;
      openFirewall = false;
    };
  };
}
