{ config, lib, ... }:
let
  cfg = config.modules.nix-settings;
in
{
  options.modules.nix-settings = {
    enable = lib.mkEnableOption "Nix flakes, caches, nh, allowUnfree" // { default = true; };
    harmonia = lib.mkEnableOption "use the harmonia binary cache from nixpc";
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

        # Never let an unreachable binary cache (e.g. the server being down)
        # stall or fail a rebuild: give up on the connection fast, then just
        # build locally instead of erroring out.
        connect-timeout = 5;
        fallback = true;

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
        # Binary cache now lives on nixpc (was home-core). Reached over Tailscale
        # MagicDNS; combined with connect-timeout + fallback above, clients keep
        # working normally when nixpc is unreachable.
        substituters = [ "http://nixpc:5000" ];
        # TODO: after nixpc's first rebuild with modules.harmonia.enable = true,
        # replace this with the contents of /var/lib/harmonia/cache-key.pub on nixpc.
        trusted-public-keys = [ "nixpc:REPLACE_WITH_NIXPC_PUBLIC_KEY" ];
      };
    })
  ]);
}
