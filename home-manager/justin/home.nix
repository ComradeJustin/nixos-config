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
      } '';
  };

  programs.carapace.enable = true;
  programs.carapace.enableNushellIntegration = true;
  # Starship prompt
  programs.starship = {
    enable = true;
  };

  programs.ghostty.enable = true;

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
    "hypr" = {
      source = link "${config.home.homeDirectory}/nixos-config/configs/hypr";
      recursive = true;
    };
  };
  # home.file.".config/ghostty".source = ../../configs/ghostty;

  gtk = {
    enable = true;
    #Icon Theme
    iconTheme = {
      package = pkgs.la-capitaine-icon-theme;
      name = "la-capitaine-icon-theme";
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
