# CUDA toolkit for compiling and running GPU programs on nixpc.
# Enter with: nix develop ~/nixos-config#cuda
#
# `pkgs` here is nixpkgs built with cudaSupport (see flake.nix), so anything
# added below is the CUDA build of that package, e.g.
# (python3.withPackages (ps: [ ps.torch ])). Those builds are downloaded from
# cache.nixos-cuda.org, which nixpc is configured to use.
{ pkgs }:
pkgs.mkShell {
  packages = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];

  # The NVIDIA driver's own libraries (libcuda and friends) are installed by
  # the system, not by this shell. This is where NixOS puts them.
  LD_LIBRARY_PATH = "/run/opengl-driver/lib";
}
