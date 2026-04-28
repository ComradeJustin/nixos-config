{ config, lib, pkgs, ... }:
{
  options.modules.audio.enable = lib.mkEnableOption "PipeWire audio stack";

  config = lib.mkIf config.modules.audio.enable {
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      extraConfig.pipewire."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 512;
          # Allow sample rate switching to match source material
          # instead of resampling everything to 48kHz
          "default.clock.allowed-rates" = [ 44100 48000 88200 96000 ];
        };
      };
      # Cap volume at 100% (0dB) to prevent digital clipping
      wireplumber.extraConfig."90-no-overamplify" = {
        "monitor.alsa.rules" = [{
          matches = [{ "node.name" = "~alsa_output.*"; }];
          actions.update-props = {
            "channelmix.max-volume" = 1.0;
            "channelmix.normalize" = false;
          };
        }];
      };
    };

    environment.systemPackages = [
      pkgs.wiremix
    ];
  };
}
