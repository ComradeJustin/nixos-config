{ config, lib, pkgs, ... }:
{
  options.modules.ai.enable = lib.mkEnableOption "AI tools (claude-code)";

  config = lib.mkIf config.modules.ai.enable {
    environment.systemPackages = with pkgs; [
      claude-code
      obsidian
    ];
  };
}
