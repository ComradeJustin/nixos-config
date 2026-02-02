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

  home.file.".config/niri".source = ../../configs/niri;
  home.file.".config/waybar".source = ../../configs/waybar;
  # home.file.".config/ghostty".source = ../../configs/ghostty;

  home.pointerCursor = {
    x11.enable = true;
    gtk.enable = true;
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
    ../../modules/programs/rofi.nix
  ];

}
