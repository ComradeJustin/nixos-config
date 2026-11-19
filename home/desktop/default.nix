# Home Manager profile for desktop machines. Imported by modules/desktop, so
# headless machines never get it.
#
# This file holds the settings that belong to the desktop as a whole. Each
# program with its own configuration has its own file beside it, and plain
# GUI apps are listed in apps.nix.
{
  config,
  pkgs,
  osConfig,
  ...
}:
let
  # Config directories are linked straight to the repository checkout, so
  # editing them applies without a rebuild.
  repository = osConfig.programs.nh.flake;
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  imports = [
    ./apps.nix
    ./ghostty.nix
    ./rofi.nix
    ./discord.nix
    ./spotify.nix
    ./music.nix
  ];

  home.sessionVariables = {
    BROWSER = "firefox";
    TERMINAL = "ghostty";
    NIXOS_OZONE_WL = "1";
  };

  xdg.configFile = {
    "niri" = {
      source = link "${repository}/configs/niri";
      recursive = true;
    };
    "quickshell" = {
      source = link "${repository}/configs/quickshell";
      recursive = true;
    };
  };

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.gruvbox-plus-icons;
      name = "Gruvbox-Plus-Dark";
    };
  };

  services.gnome-keyring.enable = true;
}
