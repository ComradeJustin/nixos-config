{ pkgs ? import <nixpkgs> {} }:
let
  fenix = import (fetchTarball "https://github.com/nix-community/fenix/archive/main.tar.gz") {};
  toolchain = fenix.stable.withComponents [
    "cargo"
    "clippy"
    "rustc"
    "rustfmt"
    "rust-analyzer"
    "rust-src"
  ];
in
pkgs.mkShell {
  packages = [
    toolchain
    pkgs.pkg-config
    pkgs.openssl
  ];
}
