{ config, lib, pkgs, ... }:
{
  options.modules.compscijava.enable = lib.mkEnableOption "computer science tools (Java, Logisim)";

  config = lib.mkIf config.modules.compscijava.enable {
    programs.nix-ld.enable = true;

    environment.systemPackages = with pkgs; [
      javaPackages.compiler.openjdk11
      wmname
      logisim-evolution
    ];
  };
}
