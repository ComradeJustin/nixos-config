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
    neovim
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

    # Man pages
    man-pages
    man-pages-posix

    # Notifications
    glib
    libnotify
  ];
}
