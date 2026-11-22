{
  description = "New Nixos System";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-packages.follows = "nixpkgs";
      inputs.nixpkgs-ci.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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

    # Runs the desktop shell (modules/desktop/shell.nix).
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
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

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # One directory per machine under hosts/. Each host's default.nix imports
  # every module that machine uses, so it is the full list of what it runs.
  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # The same nixpkgs with every package built against CUDA. Only the cuda
      # dev shell uses it; the systems themselves stay on the normal builds.
      cudaPkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
        };
      };
    in
    {
      # Development environments, pinned by this flake's lock file.
      # Enter one with: nix develop ~/nixos-config#<name>
      devShells.${system} = {
        ctf = import ./shells/ctf.nix { inherit pkgs; };
        rust = import ./shells/rust.nix { inherit pkgs; };
        cuda = import ./shells/cuda.nix { pkgs = cudaPkgs; };
      };

      nixosConfigurations = {
        nixpc = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/nixpc ];
        };

        nixlaptop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/nixlaptop ];
        };
      };
    };
}
