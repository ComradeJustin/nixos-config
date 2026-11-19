# nixpc: the always-on headless server (Intel CPU, NVIDIA GPU). Runs the
# binary cache, DNS ad blocking, the Tailscale exit node, file shares and the
# public website, and is the remote builder for nixlaptop.
{ ... }:
let
  lanInterface = "enp4s0";
in
{
  imports = [
    ./hardware-configuration.nix
    ./filesystems.nix
    ./gpu.nix

    ../../modules/base.nix
    ../../modules/nvf.nix
    ../../modules/tailscale.nix
    ../../modules/server/adguard.nix
    ../../modules/server/harmonia.nix
    ../../modules/server/samba.nix
    ../../modules/server/website.nix
  ];

  networking.hostName = "nixpc";

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
    theme = ../../assets/grub-themes/sayonara;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # --- LAN ---
  networking.interfaces.${lanInterface}.wakeOnLan.enable = true;

  # The LAN gets full access to every port, like the tailnet does. Only
  # globally opened ports are reachable from the WAN if port-forwarded.
  networking.firewall.trustedInterfaces = [ lanInterface ];

  # --- Tailscale exit node: forward traffic and advertise the role ---
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
  services.tailscale.extraSetFlags = [ "--advertise-exit-node" ];

  # --- Never sleep: DNS, the cache and the exit node must stay up ---
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
