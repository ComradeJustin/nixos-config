# Rust toolchain from nixpkgs. Enter with: nix develop ~/nixos-config#rust
{ pkgs }:
pkgs.mkShell {
  packages = with pkgs; [
    cargo
    rustc
    clippy
    rustfmt
    rust-analyzer
    pkg-config
    openssl
  ];

  # Lets rust-analyzer find the standard library's source.
  RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
}
