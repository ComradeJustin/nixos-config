{
  config,
  lib,
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
    shellAliases = {
      ctf = "nix-shell ~/nixos-config/shells/ctf.nix";
      rebuild = "~/nixos-config/scripts/rebuild.sh";
      update = "~/nixos-config/scripts/update.sh";
      wake = "~/nixos-config/scripts/wake.sh";
      infra-status = "~/nixos-config/scripts/status.sh";
    };
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

      # Sync harmonia cache key from server
      def fetch-cache-key [] {
        ssh root@home-core 'cat /var/lib/harmonia/cache-key.pem' | sudo tee /var/lib/harmonia-cache-key.pem | ignore; sudo chmod 600 /var/lib/harmonia-cache-key.pem; echo 'Cache key synced.'
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

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.gruvbox-plus-icons;
      name = "Gruvbox-Plus-Dark";
    };
  };

  imports = [
    ./modules/git.nix
    ./modules/rofi.nix
  ];
  services.cliphist = {

    enable = true;

    systemdTargets = [ "config.wayland.systemd.target" ];

    extraOptions = [
      "-max-dedupe-search"
      "10"
      "-max-items"
      "500"
    ];
    allowImages = true;

  };
  # Environment
  home.sessionVariables = {
    EDITOR = "nvim";
    BROWSER = "firefox"; 
    TERMINAL = "ghostty";
    NIXOS_OZONE_WL = "1";
  };
}
