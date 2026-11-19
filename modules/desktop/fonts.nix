# Fonts used by the desktop, the shell widgets and terminals.
{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    inter
    ibm-plex
    jetbrains-mono
    maple-mono.NF
    fraunces # display serif — QuickShell lock clock, Spotlight, headers
    hanken-grotesk # UI / body sans — QuickShell panels

    noto-fonts-cjk-sans
    sarasa-gothic

    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack

    cozette
  ];
}
