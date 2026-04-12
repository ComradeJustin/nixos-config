{ config, lib, ... }:
let
  cfg = config.modules.nix-settings;
in
{
  options.modules.nix-settings = {
    enable = lib.mkEnableOption "Nix flakes, caches, nh, allowUnfree" // { default = true; };
    harmonia = lib.mkEnableOption "use harmonia binary cache from home-core";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
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
    }

    (lib.mkIf cfg.harmonia {
      nix.settings = {
        substituters = [ "http://home-core:5000" ];
        trusted-public-keys = [ "home-core:PKqcAFp4zDgCAkasGYDMi9Ybn9Pyoyo7F9/pflz6lRw=" ];
      };
    })
  ]);
}
