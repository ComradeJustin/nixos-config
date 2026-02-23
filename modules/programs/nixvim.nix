{
  config,
  pkgs,
  inputs,
  ...
}:
{
  programs.nixvim = {
    extraPlugins = [ pkgs.vimPlugins.gruvbox ];
    colorscheme = "gruvbox";
  };

}
