# Desktop programs that need system integration (drivers, groups, wrappers).
# Plain GUI apps do not belong here: add those to home/desktop/apps.nix.
{ pkgs, ... }:
{
  programs.firefox.enable = true;
  programs.wireshark.enable = true;

  # Drawing tablet driver
  hardware.opentabletdriver.enable = true;
  hardware.opentabletdriver.daemon.enable = true;

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-vaapi # optional AMD hardware acceleration
      obs-gstreamer
      obs-vkcapture
    ];
  };
}
