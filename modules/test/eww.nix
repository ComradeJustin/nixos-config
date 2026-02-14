{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    eww
  ];
}
