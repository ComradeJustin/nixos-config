{
  config,
  pkgs,
  inputs,
  ...
}:

{

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
  home.packages = with pkgs; [
    waybar
    niri
    nixfmt-rfc-style
  ];
  home.pointerCursor = {
    name = "capitaine-cursors";
    package = pkgs.capitaine-cursors;
    size = 60;
  };

  imports = [
    ../../modules/programs/git.nix
  ];

}
