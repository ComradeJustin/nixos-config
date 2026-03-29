{ ... }:
{
  networking.hostName = "home-core";

  # Open HTTP/HTTPS for public-facing sites (nginx handles reverse proxy)
  # Additional ports managed by module enables (tailscale, etc.)
}
