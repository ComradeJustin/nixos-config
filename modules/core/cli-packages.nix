{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Shell and utilities
    nushell
    carapace
    jq
    fzf
    unzip

    # Core CLI tools
    vim
    wget
    git
    lazygit

    # System monitoring
    btop
    fastfetch
    nitch

    # Development
    gcc
    ffmpeg
    nixfmt-rfc-style
    nodejs
    python3

    # Notifications
    glib
    libnotify

    # Media CLI
    ani-cli
    inputs.lobster.packages.${pkgs.system}.lobster
    inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default

    # AI
    claude-code
  ];
}
