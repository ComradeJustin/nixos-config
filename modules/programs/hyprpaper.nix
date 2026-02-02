{
  config,
  pkgs,
  inputs,
  ...
}:
{

  services.hyprpaper = {
    enable = true;
    settings = {
      wallpaper = [

        "../../assets/wallpapers/wallpaper.png"
      ];
    };
  };
}
