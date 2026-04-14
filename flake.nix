{
  description = "New Nixos System";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-nixcord.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    awww = {
      # Pinned: crop_gravity merge (0a62aca) broke CacheEntry::new call sites
      # url = "git+https://codeberg.org/LGFae/awww";
      url = "git+https://codeberg.org/LGFae/awww?rev=efc4c492a30d7e098541ad0ca95c22287cbc26ba";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qml-niri = {
      url = "github:imiric/qml-niri/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lobster = {
      url = "github:justchokingaround/lobster";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    apple-fonts.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";


    spotatui = {
      url = "github:LargeModGames/spotatui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-beta = {
      url = "github:niri-wm/niri/wip/branch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      stylix,
      spicetify-nix,
      quickshell,
      qml-niri,
      apple-fonts,
      nixos-hardware,
      niri-beta,
      spotatui,
      disko,
      ...
    }@inputs:
    let
      # Overlays to fix package issues
      overlays = [
        (import ./overlays/btop-icon-fix.nix)
      ];

      # All module definitions — options are registered but nothing activates without enables
      sharedModules = [
        ./modules/core
        ./modules/desktop
        ./modules/server
        ./modules/hardware
        ./modules/hosts
        ./modules/profiles
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        disko.nixosModules.disko
        inputs.spicetify-nix.nixosModules.default
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.justin = import ./home-manager/justin/home.nix;
            backupFileExtension = "backup";
          };
        }
      ];

      # Helper function to create a host configuration
      mkHost = { hostModules }:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = sharedModules ++ hostModules ++ [
            { nixpkgs.overlays = overlays; }
          ];
        };
    in
    {
      nixosConfigurations = {
        nixpc = mkHost {
          hostModules = [
            ./hosts/nixpc/hardware-configuration.nix
            ./hosts/nixpc/gpu.nix
            ./hosts/nixpc/networking.nix
            {
              modules.boot.loader = "grub-efi";
              boot.loader.grub.useOSProber = true;
              boot.loader.grub.theme = ./assets/grub-themes/sayonara;
              modules.profiles.desktop.enable = true;
              modules.gaming.enable = true;
              modules.compscijava.enable = true;
              modules.ai.enable = true;
              modules.nix-settings.harmonia = true;
              modules.distributed-builds.enable = true;
              modules.distributed-builds.role = "builder";
            }
          ];
        };

        nixlaptop = mkHost {
          hostModules = [
            ./hosts/nixlaptop/hardware-configuration.nix
            ./hosts/nixlaptop/networking.nix
            nixos-hardware.nixosModules.lenovo-thinkpad-t14-intel-gen1
            {
              modules.nix-settings.harmonia = true;
              modules.profiles.desktop.enable = true;
              modules.hosts.laptop.enable = true;
              modules.fingerprint.enable = true;
              modules.bluetooth.enable = true;
              modules.compscijava.enable = true;
              modules.ai.enable = true;
              modules.distributed-builds.enable = true;
              modules.distributed-builds.role = "client";
              modules.distributed-builds.builders = [
                { hostName = "nixpc"; maxJobs = 8; speedFactor = 2; }
              ];
            }
          ];
        };

        home-core = mkHost {
          hostModules = [
            { hardware.facter.reportPath = ./hosts/servers/home-core/facter.json; }
            ./hosts/servers/home-core/disk-config.nix
            ./hosts/servers/home-core/filesystems.nix
            ./hosts/servers/home-core/networking.nix
            {
              modules.profiles.server.enable = true;
              modules.boot.loader = "grub-mbr";
              modules.tailscale.enable = true;
              modules.tailscale.exitNode = true;
              modules.tailscale.funnel = true;
              modules.tailscale.funnelPort = 8443;
              modules.tailscale.trustedLanInterfaces = [ "enp9s0" ];
              modules.nginx.enable = true;
              modules.docker.enable = true;
              modules.harmonia.enable = true;
              modules.monitoring.enable = true;
              modules.mediastack.enable = true;
              modules.adguard.enable = true;
              modules.blog.enable = true;

              modules.status-reporter.enable = true;
              modules.status-reporter.services = [
                "nginx"
                "tailscaled"
                "harmonia"
                "nix-daemon"
                "grafana"
                "adguardhome"
                "jellyfin"
                "radarr"
                "sonarr"
              ];
            }
          ];
        };
      };
    };
}
