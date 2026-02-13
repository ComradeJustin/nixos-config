{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  programs.nix-ld.enable = true;
  environment.systemPackages = with pkgs; [
    javaPackages.compiler.openjdk11
    wmname
    logisim-evolution
  ];
}
