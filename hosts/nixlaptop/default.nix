# nixlaptop: ThinkPad T14 (Intel). The desktop machine. Uses nixpc as its
# binary cache and remote builder when nixpc is reachable.
{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    # This machine's hardware
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-intel-gen1
    ./ethernet.nix
    ./power.nix
    ./fingerprint.nix
    ./bluetooth.nix

    # Shared modules
    ../../modules/base.nix
    ../../modules/editor.nix
    ../../modules/tailscale.nix
    ../../modules/desktop
  ];

  networking.hostName = "nixlaptop";

  boot.loader.limine.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Keep /tmp in memory.
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "60%";
  };

  # Video decode and encode drivers for the Intel GPU. This replaces the list
  # nixos-hardware sets, which also carries the OpenCL runtime: nothing here
  # uses OpenCL, and that package had to be compiled locally on every update.
  hardware.graphics.extraPackages = lib.mkForce [
    pkgs.intel-media-driver
    pkgs.vpl-gpu-rt
  ];

  # SSH is reachable over the tailnet only (the firewall trusts that
  # interface), not from whatever network the laptop happens to be on.
  services.openssh.openFirewall = false;

  environment.sessionVariables.CUPS_USER = "remote user";

  # --- nixpc as binary cache and remote builder, reached over Tailscale ---
  # nixpc is allowed as a cache but not used by default: as a default, every
  # Nix command waited about six seconds on it whenever nixpc was unreachable.
  # scripts/rebuild.sh switches it on for a rebuild when nixpc answers.
  nix.settings.trusted-substituters = [ "http://nixpc:5000" ];
  nix.settings.trusted-public-keys = [ "nixpc:x9xt+nopM/5hQW/6d9hAzilOIFurley0+Vq9p21CV8A=" ];

  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;
  nix.buildMachines = [
    {
      hostName = "nixpc";
      system = "x86_64-linux";
      protocol = "ssh-ng";
      # Tailscale SSH handles the login, so there is no key to manage.
      sshUser = "justin";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [
        "nixos-test"
        "big-parallel"
        "kvm"
      ];
    }
  ];
}
