# nixpc: the always-on headless server (Intel CPU, NVIDIA GPU). Runs the
# binary cache, DNS ad blocking, the Tailscale exit node, file shares and the
# public website, and is the remote builder for nixlaptop.
{ ... }:
let
  lanInterface = "enp4s0";
  lanSubnet = "192.168.1.0/24";
  # Tailscale's address ranges (IPv4 and IPv6).
  tailnetSubnets = "100.64.0.0/10 fd7a:115c:a1e0::/48";
in
{
  imports = [
    ./hardware-configuration.nix
    ./filesystems.nix
    ./gpu.nix

    ../../modules/base.nix
    ../../modules/editor.nix
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

  # --- CUDA ---
  # The system itself is not built with CUDA. GPU work happens in the cuda dev
  # shell (shells/cuda.nix), and this cache has those packages prebuilt.
  nix.settings.substituters = [ "https://cache.nixos-cuda.org" ];
  nix.settings.trusted-public-keys = [
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];

  # --- LAN ---
  networking.interfaces.${lanInterface}.wakeOnLan.enable = true;

  # The LAN reaches only DNS and the file shares (SSH is open everywhere,
  # see modules/base.nix). The binary cache and everything else are
  # tailnet-only.
  networking.firewall.interfaces.${lanInterface} = {
    allowedTCPPorts = [
      53 # DNS (AdGuard)
      445 # Samba
      5357 # Windows network discovery (wsdd)
    ];
    allowedUDPPorts = [
      53 # DNS (AdGuard)
      3702 # Windows network discovery (wsdd)
    ];
  };

  # Samba answers only the LAN, the tailnet and this machine itself.
  services.samba.settings.global = {
    "hosts allow" = "${lanSubnet} ${tailnetSubnets} 127.0.0.1 ::1";
    "hosts deny" = "ALL";
  };

  # Emergency recovery: root may log in over SSH from the LAN, with this key
  # only. Root has no password.
  services.openssh.extraConfig = ''
    Match User root Address ${lanSubnet}
        PermitRootLogin prohibit-password
  '';
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICiBr6+h5wioJw5BYXefcyX2w2Ytw3EfAayCeGsBaLQC root-recovery"
  ];

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
