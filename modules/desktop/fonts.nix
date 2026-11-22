# Fonts used by the desktop, the shell widgets and terminals.
{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    inter
    ibm-plex
    jetbrains-mono
    maple-mono.NF
    fraunces # display serif, for configs/fabric
    hanken-grotesk # UI and body sans, for configs/fabric

    noto-fonts-cjk-sans
    sarasa-gothic

    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.departure-mono # the shell's pixel font (configs/shell)

    cozette
  ];
}
