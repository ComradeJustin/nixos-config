# PipeWire audio.
{ pkgs, ... }:
{
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    # Cap volume at 100% (0dB) to prevent digital clipping
    wireplumber.extraConfig."90-no-overamplify" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.*"; } ];
          actions.update-props = {
            "channelmix.max-volume" = 1.0;
            "channelmix.normalize" = false;
          };
        }
      ];
    };
  };

  environment.systemPackages = [
    pkgs.wiremix
  ];
}
