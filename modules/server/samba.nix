# Samba file server: one shared folder plus a personal folder per user.
# Not opened in the firewall; reachable via trusted interfaces only.
{ config, lib, ... }:
let
  # Root directory for the shared share
  dataDir = "/srv";
  # Root directory for per-user personal folders
  homeDir = "/home/samba";
  # Users with read/write access to all shares
  admins = [ "justin" ];
  # Samba-only users (no shell, no login — only SMB access). Each gets a personal folder.
  sambaUsers = [ ];

  allUsers = admins ++ sambaUsers;
  adminStr = lib.concatStringsSep " " admins;
  allUsersStr = lib.concatStringsSep " " allUsers;

  # Shared folder — points to dataDir root, everyone rw via samba group
  sharedShare = {
    shared = {
      path = dataDir;
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
  userShares = lib.listToAttrs (
    map (name: {
      inherit name;
      value = {
        path = "${homeDir}/${name}";
        "read only" = "no";
        browseable = "yes";
        "valid users" = "${name} ${adminStr}";
        "force group" = "samba";
        "create mask" = "0660";
        "directory mask" = "2770";
        "inherit permissions" = "yes";
      };
    }) allUsers
  );
in
{
  # All samba participants need the samba group
  users.groups.samba = { };

  # Samba-only users: no shell, no login, no sudo — exist purely for SMB auth
  # Admin users: add samba group
  users.users = lib.mkMerge [
    (lib.listToAttrs (
      map (name: {
        inherit name;
        value = {
          isSystemUser = true;
          group = "samba";
          shell = "/run/current-system/sw/bin/nologin";
          home = "/var/empty";
          createHome = false;
        };
      }) sambaUsers
    ))
    (lib.listToAttrs (
      map (name: {
        inherit name;
        value = {
          extraGroups = [ "samba" ];
        };
      }) admins
    ))
  ];

  services.samba = {
    enable = true;
    openFirewall = false;

    settings = {
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
    }
    // sharedShare
    // userShares;
  };

  # Create share directories with correct ownership
  systemd.tmpfiles.rules =
    # Shared directory — setgid so new dirs inherit samba group
    [ "d ${dataDir} 2775 ${builtins.head admins} samba -" ]
    # Home directory root
    ++ [ "d ${homeDir} 0755 root samba -" ]
    # Per-user folders — setgid, owned by user, group samba
    ++ map (name: "d ${homeDir}/${name} 2770 ${name} samba -") allUsers;

  # Enable wsdd for Windows network discovery
  services.samba-wsdd = {
    enable = true;
    openFirewall = false;
  };
}
