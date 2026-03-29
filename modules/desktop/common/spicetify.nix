{ config, lib, pkgs, inputs, ... }:
{
  options.modules.spicetify.enable = lib.mkEnableOption "Spicetify (modded Spotify)";

  config = lib.mkIf config.modules.spicetify.enable {
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
    ];
  home-manager.sharedModules = [
    (
      { pkgs, ... }:
      let
        spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        imports = [ inputs.spicetify-nix.homeManagerModules.default ];

        programs.spicetify = {
          enable = true;
          enabledExtensions = with spicePkgs.extensions; [
            adblock
            shuffle
            keyboardShortcut
            copyLyrics
          ];
          enabledCustomApps = with spicePkgs.apps; [
            lyricsPlus
          ];
        };
      }
    )
  ];
  };
}
