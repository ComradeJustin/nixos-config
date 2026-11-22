# PipeWire audio.
{ pkgs, ... }:
{
  # Hands PipeWire realtime scheduling priority. Without it audio threads
  # compete with everything else and can crackle or drop out under load.
  security.rtkit.enable = true;

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
