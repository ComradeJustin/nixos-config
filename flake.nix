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

    # Desktop shell (TypeScript/GTK4 on Astal). Eventual successor to the
    # quickshell bar. nixpkgs ships ags 2.x; the flake is v3 (gnim JSX, GTK4),
    # which is what the docs describe.
    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Trackpad-first infinite canvas compositor, installed beside niri so it
    # can be picked at the greeter.
    driftwm = {
      url = "github:malbiruk/driftwm";
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
  };

  # One directory per machine under hosts/. Each host's default.nix imports
  # every module that machine uses, so it is the full list of what it runs.
  outputs =
    { nixpkgs, ... }@inputs:
    {
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
