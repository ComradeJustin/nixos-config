{
  description = "New Nixos System";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-nixcord.follows = "nixpkgs";
    };

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
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

    # Desktop widgets (Python/GTK). Not nixpkgs `fabric`. Must follow our
    # nixpkgs: an older GTK/fontconfig than the system misparses font rules.
    fabric = {
      url = "github:Fabric-Development/fabric";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop shell (TypeScript/GTK4 on Astal). Successor to both the fabric
    # overlay and, eventually, the quickshell bar. nixpkgs ships ags 2.x;
    # the flake is v3 (gnim JSX, GTK4), which is what the docs describe.
    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lobster = {
      url = "github:justchokingaround/lobster";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";

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
      nixos-hardware,
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
      mkHost =
        { hostModules }:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules =
            sharedModules
            ++ hostModules
            ++ [
              { nixpkgs.overlays = overlays; }
            ];
        };
    in
    {
      nixosConfigurations = {
        nixpc = mkHost {
          hostModules = [
            ./hosts/nixpc/hardware-configuration.nix
            ./hosts/nixpc/filesystems.nix
            ./hosts/nixpc/gpu.nix
            ./hosts/nixpc/networking.nix
            {
              modules.boot.loader = "grub-efi";
              boot.loader.grub.useOSProber = true;
              boot.loader.grub.theme = ./assets/grub-themes/sayonara;
              modules.profiles.desktop.enable = false;
              modules.gaming.enable = false;
              modules.compscijava.enable = true;
              modules.ai.enable = true;
              modules.distributed-builds.enable = true;
              modules.distributed-builds.role = "builder";
              modules.godot.enable = true;
              modules.smb-client.enable = true;

              # --- Server role (migrated from home-core) ---
              # nixpc is now the binary-cache server, so it does NOT pull from a
              # harmonia substituter itself (modules.nix-settings.harmonia stays off).
              modules.tailscale.enable = true;
              modules.tailscale.exitNode = true;
              modules.tailscale.trustedLanInterfaces = [ "enp4s0" ];
              modules.adguard.enable = true;
              modules.harmonia.enable = true;
              modules.samba.enable = true;
              modules.website.enable = true;

              # VNC attaches to the niri session, which is off with the desktop.
              modules.wayvnc.enable = false;
              modules.wayvnc.output = "DP-2";

              # Permanent server: never auto-suspend. The shared niri startup.kdl
              # runs `swayidle ... timeout 1800 systemctl suspend`, which would take
              # DNS/cache/exit-node offline after 30 min idle. Mask sleep so that
              # `systemctl suspend` becomes a harmless no-op on this host only.
              systemd.targets.sleep.enable = false;
              systemd.targets.suspend.enable = false;
              systemd.targets.hibernate.enable = false;
              systemd.targets.hybrid-sleep.enable = false;
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
              modules.profiles.laptop.enable = true;
              modules.fingerprint.enable = true;
              modules.bluetooth.enable = true;
              modules.compscijava.enable = true;
              modules.ai.enable = true;
              modules.distributed-builds.enable = true;
              modules.distributed-builds.role = "client";
              modules.distributed-builds.builders = [
                {
                  hostName = "nixpc";
                  maxJobs = 8;
                  speedFactor = 2;
                }
              ];

              modules.smb-client.enable = true;
            }
          ];
        };

        # home-core: still running, but managed outside this flake since its
        # always-on role (exit node, DNS, cache, samba) moved to nixpc.
        # To manage it from here again, add a mkHost entry using
        # ./hosts/servers/home-core/ and the server modules it needs.
      };
    };
}
