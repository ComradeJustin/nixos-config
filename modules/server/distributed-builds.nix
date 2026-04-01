{ config, lib, pkgs, ... }:
let
  cfg = config.modules.distributed-builds;
  isBuilder = cfg.role == "builder" || cfg.role == "both";
  isClient = cfg.role == "client" || cfg.role == "both";
in
{
  options.modules.distributed-builds = {
    enable = lib.mkEnableOption "distributed Nix remote builds";

    role = lib.mkOption {
      type = lib.types.enum [ "builder" "client" "both" ];
      default = "builder";
      description = "Whether this machine serves builds, sends builds, or both";
    };

    transport = lib.mkOption {
      type = lib.types.enum [ "tailscale" "ssh" ];
      default = "tailscale";
      description = ''
        Transport for remote builds.
        - tailscale: uses Tailscale SSH (no key management, machines auth via tailnet)
        - ssh: traditional SSH with a shared builder keypair
      '';
    };

    sshKey = lib.mkOption {
      type = lib.types.str;
      default = "/root/.ssh/nix-builder";
      description = "Path to shared SSH private key (only used with transport = ssh)";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Public keys authorized to build on this machine (only used with transport = ssh)";
    };

    builders = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          hostName = lib.mkOption {
            type = lib.types.str;
            description = "Tailscale hostname or SSH address of the builder";
          };
          system = lib.mkOption { type = lib.types.str; default = "x86_64-linux"; };
          maxJobs = lib.mkOption { type = lib.types.int; default = 4; };
          speedFactor = lib.mkOption { type = lib.types.int; default = 1; };
          supportedFeatures = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "nixos-test" "big-parallel" "kvm" ];
          };
        };
      });
      default = [ ];
      description = "Remote builders this client can send builds to";
    };

  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Tailscale transport: ensure tailscale is enabled
    (lib.mkIf (cfg.transport == "tailscale") {
      modules.tailscale.enable = lib.mkDefault true;

      # Tailscale SSH handles auth — nix daemon connects as root via tailscale
      services.tailscale.extraSetFlags = [ "--ssh" ];
    })

    # Builder role: accept remote build jobs
    (lib.mkIf isBuilder (lib.mkMerge [
      {
        nix.settings.trusted-users = [ "nix-builder" "root" ];
      }

      # SSH transport: create builder user with authorized keys
      (lib.mkIf (cfg.transport == "ssh") {
        users.users.nix-builder = {
          isNormalUser = true;
          description = "Nix remote builder user";
          openssh.authorizedKeys.keys = cfg.authorizedKeys;
        };
      })
    ]))

    # Client role: send builds to remote machines + build locally in parallel
    (lib.mkIf isClient {
      nix.distributedBuilds = true;
      nix.settings.builders-use-substitutes = true;

      nix.buildMachines = [
        # Local machine as a builder so Nix uses both local + remote simultaneously
        {
          hostName = "localhost";
          system = "x86_64-linux";
          maxJobs = 4;
          speedFactor = 1;
          supportedFeatures = [ "nixos-test" "big-parallel" "kvm" ];
        }
      ] ++ map (b: {
        inherit (b) hostName system maxJobs speedFactor supportedFeatures;
        protocol = "ssh-ng";
        sshUser = if cfg.transport == "tailscale" then "root" else "nix-builder";
        sshKey = if cfg.transport == "tailscale" then null else cfg.sshKey;
      }) cfg.builders;
    })
  ]);
}
