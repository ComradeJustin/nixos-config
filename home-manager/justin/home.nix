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

  home.file.".config/niri".source = ../../configs/niri;
  home.file.".config/waybar".source = ../../configs/waybar;
  home.file.".config/ghostty".source = ../../configs/ghostty;

  home.pointerCursor = {
    name = "capitaine-cursors";
    package = pkgs.capitaine-cursors;
    size = 60;
  };
  gtk = {
    enable = true;
    #Icon Theme
    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };
  };

  imports = [
    ../../modules/programs/git.nix
  ];

}
