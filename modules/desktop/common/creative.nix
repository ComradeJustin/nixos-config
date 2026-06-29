{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.creative.enable = lib.mkEnableOption "creative apps (Krita, GIMP, OpenTabletDriver)";

  config = lib.mkIf config.modules.creative.enable {
    hardware.opentabletdriver.enable = true;
    hardware.opentabletdriver.daemon.enable = true;
    programs.obs-studio = {
      enable = true;

      # optional Nvidia hardware acceleration
      package = (
        pkgs.obs-studio.override {
          cudaSupport = true;
        }
      );

      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        obs-vaapi # optional AMD hardware acceleration
        obs-gstreamer
        obs-vkcapture
      ];
    };
    environment.systemPackages = with pkgs; [
      krita
      gimp
      audacity
    ];
  };
}
