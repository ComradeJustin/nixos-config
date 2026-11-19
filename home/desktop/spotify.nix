# Spotify with Spicetify extensions.
{ inputs, pkgs, ... }:
let
  spicetifyPackages = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;
    enabledExtensions = with spicetifyPackages.extensions; [
      adblock
      shuffle
      keyboardShortcut
      copyLyrics
    ];
    enabledCustomApps = with spicetifyPackages.apps; [
      lyricsPlus
    ];
  };
}
