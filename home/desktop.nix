# Home Manager profile for desktop machines: GUI apps and their config.
# Imported by modules/desktop, so headless machines never get it.
#
# To add a GUI app, add it to home.packages below.
{
  config,
  inputs,
  pkgs,
  osConfig,
  ...
}:
let
  # Config directories are linked straight to the repository checkout, so
  # editing them applies without a rebuild.
  repository = osConfig.programs.nh.flake;
  link = config.lib.file.mkOutOfStoreSymlink;

  spicetifyPackages = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./mpd.nix
    inputs.nixcord.homeModules.nixcord
    inputs.spicetify-nix.homeManagerModules.default
  ];

  home.sessionVariables = {
    BROWSER = "firefox";
    TERMINAL = "ghostty";
    NIXOS_OZONE_WL = "1";
  };

  home.packages = with pkgs; [
    # Apps
    vscode
    code-cursor
    nautilus
    pavucontrol
    nicotine-plus

    # Creative
    krita
    gimp
    audacity

    # Media
    (mpv.override { scripts = [ mpvScripts.mpris ]; })
    imv
    feh
    ffmpeg
    imagemagick
    ani-cli
    inputs.lobster.packages.${pkgs.stdenv.hostPlatform.system}.lobster
    spotatui

    # Coursework
    logisim-evolution
    wmname
  ];

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

  programs.ghostty = {
    enable = true;
    settings = {
      quit-after-last-window-closed = false;
    };
  };

  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    settings = {
      modes = [
        "drun"
        "run"
        "window"
        "ssh"
      ];
      show-icons = true;
    };
  };

  programs.nixcord = {
    enable = true;
    vesktop.enable = true;
  };

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

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.gruvbox-plus-icons;
      name = "Gruvbox-Plus-Dark";
    };
  };

  stylix.targets.vscode.profileNames = [
    "Default"
    "default"
  ];

  services.gnome-keyring.enable = true;
}
