{ config, lib, pkgs, inputs, ... }:
{
  options.modules.media-cli.enable = lib.mkEnableOption "media CLI tools (mpv, ffmpeg, ani-cli, lobster, spotatui)";

  config = lib.mkIf config.modules.media-cli.enable {
    environment.systemPackages = with pkgs; [
      mpv
      imv
      ffmpeg
      imagemagick
      ani-cli
      inputs.lobster.packages.${pkgs.system}.lobster
      inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
