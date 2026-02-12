{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    javaPackages.compiler.openjdk11
  ];
}
