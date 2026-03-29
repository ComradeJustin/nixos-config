{
  imports = [
    ./docker.nix
    ./nginx.nix
    ./postgres.nix
    ./tailscale.nix
    ./monitoring.nix
    ./distributed-builds.nix
  ];
}
