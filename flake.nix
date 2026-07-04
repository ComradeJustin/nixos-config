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
      url = "git+https://codeberg.org/LGFae/awww";
      #url = "git+https://codeberg.org/LGFae/awww?rev=efc4c492a30d7e098541ad0ca95c22287cbc26ba";
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

    nixos-hardware.url = "github:NixOS/nixos-hardware";


    spotatui = {
      url = "github:LargeModGames/spotatui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:niri-wm/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
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
      niri,
      spotatui,
      disko,
      sops-nix,
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
        sops-nix.nixosModules.sops
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
            ./hosts/nixpc/filesystems.nix
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

              # Always-on VNC into the running niri session (localhost only;
              # reach via `ssh -L 5900:127.0.0.1:5900 nixpc`). Starts on DP-2;
              # switch live with `wayvncctl output-set HDMI-A-1`.
              modules.wayvnc.enable = true;
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
                { hostName = "nixpc"; maxJobs = 8; speedFactor = 2; }
              ];

              modules.smb-client.enable = true;
            }
          ];
        };

        # home-core: decommissioned — its server role (Tailscale exit node,
        # AdGuard DNS, harmonia cache, samba) migrated to nixpc above.
        # Host files remain under ./hosts/servers/home-core/ for reference/recovery.
      };
    };
}
