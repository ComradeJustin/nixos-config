{ config, lib, pkgs, ... }:
{
  options.modules.devtools.enable = lib.mkEnableOption "development tools (compilers, runtimes, build tools)";

  config = lib.mkIf config.modules.devtools.enable {
    environment.systemPackages = with pkgs; [
      gcc
      gnumake
      pkg-config
      nodejs
      python3
      direnv
      nix-direnv
      nixfmt-rfc-style
      tmux
      nix-output-monitor
    ];
  };
}
