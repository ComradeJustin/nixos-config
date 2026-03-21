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
    zip
    p7zip
    zstd

    # Core CLI tools
    vim
    wget
    curl
    git
    lazygit
    gh

    # Modern CLI replacements
    fd
    ripgrep
    bat
    eza
    dust
    zoxide
    tealdeer

    # System monitoring
    btop
    fastfetch
    nitch

    # Development
    nix-output-monitor
    tmux
    gcc
    ffmpeg
    nixfmt-rfc-style
    nodejs
    python3
    direnv
    nix-direnv
    gnumake
    pkg-config

    # Network tools
    dnsutils
    traceroute
    iperf3

    # Man pages
    man-pages
    man-pages-posix

    # Notifications
    glib
    libnotify

    # Media CLI
    ani-cli
    inputs.lobster.packages.${pkgs.system}.lobster
    inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Media
    mpv
    imv
    imagemagick

    # AI
    claude-code
    mgrep
  ];
}
