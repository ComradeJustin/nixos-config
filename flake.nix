{
  description = "New Nixos System";
  inputs = {
    # nixpkgs-stable.url = "nixpkgs/nixos-25.11";
    nixpkgs.url = "nixpkgs/nixos-unstable"; # Uses unstable for everything

    # For discord
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # For Spicetify
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # For Wallpapers:

    awww.url = "git+https://codeberg.org/LGFae/awww";
    # For Stylix
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

    # For Home manager

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # San Francisco Fonts | Apple Fonts
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    apple-fonts.inputs.nixpkgs.follows = "nixpkgs";
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
      ...
    }@inputs:
    {

      nixosConfigurations = {
        nixpc =
          let
            hostname = "nixpc";
          in
          nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs;
            };

            system = "x86_64-linux";
            # Basically a replacement to Configuration.nix
            modules = [

              # Main system
              ./main/configuration.nix
              ./hosts/nixpc/hardware-configuration.nix
              # Groups of programs
              ./modules/core/fonts.nix
              ./modules/core/programs.nix
              ./modules/core/cli-packages.nix
              ./modules/core/services.nix

              # Current WM and its collection of configs
              ./modules/extras/niri-system.nix

              # Extra Set of programs
              ./modules/extras/gaming.nix
              ./hosts/nixpc/gpu.nix
              ./hosts/nixpc/networking.nix
              ./modules/services/portals.nix
              # Theme
              stylix.nixosModules.stylix

              # Home manager
              home-manager.nixosModules.home-manager

              # Spotify
              inputs.spicetify-nix.nixosModules.default

              # Extra programming stuff
              ./modules/extras/compscijava.nix

              # Testing stuff to be implemented
              ./modules/test/quickshell.nix
              {

                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users.justin = import ./home-manager/justin/home.nix;
                  backupFileExtension = "backup";
                };
              }
            ];
          };
        nixlaptop =
          let
            hostname = "nixlaptop";
          in
          nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs;
            };

            system = "x86_64-linux";
            # Basically a replacement to Configuration.nix
            modules = [

              # Main system
              ./main/configuration.nix
              ./hosts/nixlaptop/hardware-configuration.nix
              # Groups of programs
              ./modules/core/fonts.nix
              ./modules/core/programs.nix
              ./modules/core/cli-packages.nix
              ./modules/core/services.nix

              # Current WM and its collection of configs
              ./modules/extras/niri-system.nix

              # Extra Set of programs
              ./modules/extras/displaymanagement.nix
              ./modules/extras/fingerprint.nix
              ./hosts/nixlaptop/networking.nix
              ./modules/services/portals.nix
              # Theme
              stylix.nixosModules.stylix

              # Home manager
              home-manager.nixosModules.home-manager

              # Spotify
              inputs.spicetify-nix.nixosModules.default

              # Extra programming stuff
              ./modules/extras/compscijava.nix

              # Modules that are being tested to be implemented
              ./modules/test/quickshell.nix
              ./modules/test/lockscreen.nix
              {

                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users.justin = import ./home-manager/justin/home.nix;
                  backupFileExtension = "backup";
                };
              }
            ];
          };

      };
    };

}
