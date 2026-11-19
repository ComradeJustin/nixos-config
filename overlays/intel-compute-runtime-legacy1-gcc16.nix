# The Gen8–11 compute runtime is frozen at 24.35. GCC 16 promotes
# -Wsfinae-incomplete to an error in NEO::Buffer, and this package builds
# with -Werror. Nix appends NIX_CFLAGS_COMPILE after CMake's flags, so this
# wins over -Werror for that warning only.
final: prev: {
  intel-compute-runtime-legacy1 = prev.intel-compute-runtime-legacy1.overrideAttrs (oldAttrs: {
    NIX_CFLAGS_COMPILE = (oldAttrs.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error=sfinae-incomplete";
  });
}
