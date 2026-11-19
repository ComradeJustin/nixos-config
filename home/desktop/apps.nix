# GUI apps that need no configuration of their own. To add an app, add it to
# the list. An app that needs settings gets its own file in this directory.
{ inputs, pkgs, ... }:
{
  home.packages = with pkgs; [
    # Apps
    vscode
    code-cursor
    nautilus
    pavucontrol
    nicotine-plus

    # Creative
    krita
    gimp
    audacity

    # Media
    (mpv.override { scripts = [ mpvScripts.mpris ]; })
    imv
    feh
    ffmpeg
    imagemagick
    ani-cli
    inputs.lobster.packages.${pkgs.stdenv.hostPlatform.system}.lobster
    spotatui

    # Coursework
    logisim-evolution
    wmname
  ];

  # Stylix themes VS Code per profile; these are the profile names it has.
  stylix.targets.vscode.profileNames = [
    "Default"
    "default"
  ];
}
