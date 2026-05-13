{ config, lib, pkgs, ... }:
{
  options.modules.godot.enable = lib.mkEnableOption "Godot 4 game engine";

  config = lib.mkIf config.modules.godot.enable {
    environment.systemPackages = with pkgs; [
      godot_4
    ];
  };
}
