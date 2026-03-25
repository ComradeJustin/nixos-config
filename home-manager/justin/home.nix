{
  config,
  pkgs,
  inputs,
  ...
}:
let
  link = config.lib.file.mkOutOfStoreSymlink;

in
{
  services.gnome-keyring.enable = true;

  home.username = "justin";
  home.homeDirectory = "/home/justin";
  home.stateVersion = "25.11";
  programs.git.enable = true;
  programs.nushell = {
    enable = true;
    extraConfig = ''
      $env.config = {
        show_banner: false,
        completions: {
          case_sensitive: false # case-sensitive completions
          quick: false        # set to false to prevent auto-selecting completions
          partial: false        # set to false to prevent partial filling of the prompt
          algorithm: "fuzzy"    # prefix or fuzzy
          external: {
            # set to false to prevent nushell looking into $env.PATH to find more suggestions
            enable: true
            # set to lower can improve completion performance at the cost of omitting some options
            max_results: 100
          }
        }
      }

      # Force 100Mbps when a switch port has auto-negotiation issues
      def eth-downshift [] {
        sudo ethtool -s enp0s31f6 speed 100 duplex full autoneg off
      }

      # Restore gigabit auto-negotiation
      def eth-gigabit [] {
        sudo ethtool -s enp0s31f6 speed 1000 duplex full autoneg on
      }
    '';
  };

  programs.atuin = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.carapace.enable = true;
  programs.carapace.enableNushellIntegration = true;
  # Starship prompt
  programs.starship = {
    enable = true;
  };

  programs.ghostty = {
    enable = true;
    settings = {
      quit-after-last-window-closed = false;
    };
  };


  # Allows me to set up config files.
  xdg.configFile = {

    "niri" = {
      source = link "${config.home.homeDirectory}/nixos-config/configs/niri";
      recursive = true;
    };
    "waybar" = {
      source = link "${config.home.homeDirectory}/nixos-config/configs/waybar";
      recursive = true;
    };
    "quickshell" = {
      source = link "${config.home.homeDirectory}/nixos-config/configs/quickshell";
      recursive = true;
    };
  };
  # home.file.".config/ghostty".source = ../../configs/ghostty;

  gtk = {
    enable = true;
    #Icon Theme
    iconTheme = {
      package = pkgs.gruvbox-plus-icons;
      name = "Gruvbox-Plus-Dark";
    };
  };

  stylix.targets.vscode.profileNames = [
    "Default"
    "default"
  ];

  imports = [

    ../../modules/programs/git.nix
    ../../modules/programs/rofi.nix
  ];
  services.cliphist = {

    enable = true;

    # A Wayland session
    systemdTargets = [ "config.wayland.systemd.target" ];

    # Sway Target
    # if using make sure that:
    # "wayland.windowManager.sway.systemd.enable = true;" is set
    #systemdTargets = ["sway-session.target"];

    extraOptions = [
      "-max-dedupe-search"
      "10"
      "-max-items"
      "500"
    ];
    allowImages = true;

  };
}
