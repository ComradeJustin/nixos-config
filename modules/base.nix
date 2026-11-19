# What every machine gets: Nix settings, the justin user, SSH, locale,
# networking, command-line tools, and the base Home Manager profile.
#
# Add a program here only if every machine should have it. GUI apps go in
# home/desktop.nix; things for a single machine go in that host's default.nix.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  # --- Nix ---
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;

    max-jobs = "auto";
    cores = 0;

    # Never let an unreachable binary cache stall or fail a rebuild: give up on
    # the connection fast, then build locally instead of erroring out.
    connect-timeout = 5;
    fallback = true;

    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    eval-cache = true;

    # justin needs to be trusted for remote deploys and distributed builds.
    trusted-users = [ "justin" ];
  };

  # The one place that says where this repository is checked out. Other
  # modules read it from here.
  programs.nh = {
    enable = true;
    flake = "/home/justin/nixos-config";
    clean = {
      enable = true;
      extraArgs = "--keep-since 30d --keep 5";
    };
  };

  # --- Firmware and disks (boot loader and kernel are set per host) ---
  services.fstrim.enable = true;
  services.fwupd.enable = true;

  # --- Locale ---
  time.timeZone = "America/Vancouver";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Network ---
  networking.networkmanager.enable = true;

  # --- SSH: keys only, port 22 open, repeated failures banned ---
  programs.ssh.enableAskPassword = false;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    extraConfig = ''
      # Allow root key-only login from LAN for emergency recovery
      Match User root Address 192.168.1.0/24
          PermitRootLogin prohibit-password
    '';
  };

  services.fail2ban.enable = true;

  # --- User ---
  users.users.justin = {
    isNormalUser = true;
    # Only used when the user is first created (fresh install) — change it
    # with `passwd` on first login. Existing machines keep their password.
    initialPassword = "changeme";
    extraGroups = [
      "wheel"
      "wireshark"
      "networkmanager"
      "lpadmin"
      "input"
    ];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHn/YMVvbeDt0NLp8tLhFc0cykp/Dq2huuhfUagVrIev chinese2000ping@gmail.com"
    ];
  };

  # Root has no password — use sudo, or the recovery key below over SSH.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICiBr6+h5wioJw5BYXefcyX2w2Ytw3EfAayCeGsBaLQC root-recovery"
  ];

  # --- Home Manager: every machine gets home/base.nix ---
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users.justin.imports = [ ../home/base.nix ];
  };

  # --- Command-line tools ---
  # Lets prebuilt binaries (downloaded toolchains, language servers) run.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # Shell and utilities
    nushell
    jq
    fzf
    unzip
    zip
    p7zip
    zstd
    tree
    tmux

    # Core tools
    neovim
    wget
    curl
    git
    lazygit
    gh
    nix-tree
    nix-output-monitor
    nixfmt

    # Modern replacements for classic tools
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
    nmap
    ethtool
    dnsutils
    traceroute
    iperf3
    cifs-utils

    # Compilers and runtimes
    gcc
    gnumake
    pkg-config
    nodejs
    python3
    javaPackages.compiler.openjdk11
    steam-run

    # AI coding tools
    claude-code
    codex

    # Man pages
    man-pages
    man-pages-posix

    # Desktop notifications from scripts
    libnotify
  ];

  system.stateVersion = "25.11";
}
