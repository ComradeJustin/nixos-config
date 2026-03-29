{ config, lib, ... }:
{
  options.modules.nix-settings.enable = lib.mkEnableOption "Nix flakes, caches, nh, allowUnfree" // { default = true; };

  config = lib.mkIf config.modules.nix-settings.enable {
    nixpkgs.config.allowUnfree = true;

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;

      max-jobs = "auto";
      cores = 0;

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      eval-cache = true;
    };

    programs.nh = {
      enable = true;
      flake = "/home/justin/nixos-config";
      clean = {
        enable = true;
        extraArgs = "--keep-since 30d --keep 5";
      };
    };
  };
}
