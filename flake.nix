{
  description = "New Nixos System";
  inputs = {

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
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # For Home manager
    nixpkgs.url = "nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
              ./modules/services/portals.nix
              stylix.nixosModules.stylix
              home-manager.nixosModules.home-manager
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
          };

      };
    };

}
