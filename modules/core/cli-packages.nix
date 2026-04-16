{ config, lib, pkgs, inputs, ... }:
{
  options.modules.cli-packages.enable = lib.mkEnableOption "CLI tools (neovim, git, ripgrep, bat, etc.)" // { default = true; };

  config = lib.mkIf config.modules.cli-packages.enable {
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
      nix-tree
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

      # Networking
      wol

      # Man pages
      man-pages
      man-pages-posix

      # Notifications
      glib
      libnotify
    ];
  };
}
