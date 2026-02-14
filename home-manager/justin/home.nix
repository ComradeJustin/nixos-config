{
  config,
  pkgs,
  inputs,
  ...
}:

{
  services.gnome-keyring.enable = true;

  home.username = "justin";
  home.homeDirectory = "/home/justin";
  home.stateVersion = "25.11";
  programs.git.enable = true;
  programs.bash = {
    enable = true;
  };
  programs.ghostty.enable = true;

  # Allows me to set up config files.
  home.file.".config/niri".source = ../../configs/niri;
  home.file.".config/waybar".source = ../../configs/waybar;
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

}
