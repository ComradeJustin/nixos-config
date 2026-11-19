# nixlaptop: ThinkPad T14 (Intel). The desktop machine. Uses nixpc as its
# binary cache and remote builder when nixpc is reachable.
{ inputs, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./ethernet.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-intel-gen1

    ../../modules/base.nix
    ../../modules/editor.nix
    ../../modules/tailscale.nix
    ../../modules/desktop
    ../../modules/laptop.nix
    ../../modules/fingerprint.nix
    ../../modules/bluetooth.nix
  ];

  networking.hostName = "nixlaptop";

  boot.loader.limine.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # The Intel GPU's OpenCL runtime needs a patch to build with GCC 16.
  nixpkgs.overlays = [ (import ../../overlays/intel-compute-runtime-legacy1-gcc16.nix) ];

  environment.sessionVariables.CUPS_USER = "remote user";

  # --- nixpc as binary cache and remote builder, reached over Tailscale ---
  # With connect-timeout and fallback (modules/base.nix), rebuilds still work
  # when nixpc is unreachable.
  nix.settings.substituters = [ "http://nixpc:5000" ];
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
