{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = [ pkgs.swayidle ];

  fonts.packages = with pkgs; [
    inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd
  ];
}
