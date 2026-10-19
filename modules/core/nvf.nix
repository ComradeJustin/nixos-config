# nvf-based Neovim, installed as a *separate* `nvf` command alongside the
# stock `neovim` (which keeps `nvim`/`vi`/`vim`). Toggle per host with
# `modules.nvf.enable`.
#
# Why standalone instead of the `programs.nvf` module: that module ships its
# own `bin/nvim`, which collides with the stock neovim package. Building a
# standalone `neovimConfiguration` and renaming the binary lets both coexist.
#
# Stylix: the native `stylix.targets.nvf` only hooks `programs.nvf`, so it
# does not apply here. We replicate its behaviour manually — feeding the same
# `config.lib.stylix.colors` palette into nvf's base16 theme — gated on
# `modules.theming.enable` so headless/server hosts (no Stylix) still build.
{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.modules.nvf;
  themingOn = config.modules.theming.enable;
  colors = config.lib.stylix.colors;

  # Mirrors stylix/modules/neovim/nvf.nix (which uses colors.withHashtag):
  # drive nvf's base16 theme from the system Stylix palette. Only included in
  # the module list when theming is on, so `colors` is never forced otherwise.
  stylixTheme = { ... }: {
    vim.theme = {
      name = "base16";
      base16-colors = {
        base00 = "#${colors.base00}";
        base01 = "#${colors.base01}";
        base02 = "#${colors.base02}";
        base03 = "#${colors.base03}";
        base04 = "#${colors.base04}";
        base05 = "#${colors.base05}";
        base06 = "#${colors.base06}";
        base07 = "#${colors.base07}";
        base08 = "#${colors.base08}";
        base09 = "#${colors.base09}";
        base0A = "#${colors.base0A}";
        base0B = "#${colors.base0B}";
        base0C = "#${colors.base0C}";
        base0D = "#${colors.base0D}";
        base0E = "#${colors.base0E}";
        base0F = "#${colors.base0F}";
      };
    };
  };

  nvfNeovim = (inputs.nvf.lib.neovimConfiguration {
    inherit pkgs;
    modules = [ ./nvf-config.nix ] ++ lib.optional themingOn stylixTheme;
  }).neovim;

  # Rename the binary so it coexists with stock neovim's `nvim`.
  nvfWrapped = pkgs.writeShellScriptBin "nvf" ''
    exec ${nvfNeovim}/bin/nvim "$@"
  '';
in
{
  options.modules.nvf.enable =
    lib.mkEnableOption "nvf-based Neovim as the `nvf` command (coexists with stock neovim)"
    // { default = true; };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ nvfWrapped ];
  };
}
