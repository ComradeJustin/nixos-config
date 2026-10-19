{ config, lib, ... }:
{
  options.modules.profiles.laptop = {
    enable = lib.mkEnableOption "laptop profile (tmpfs, TLP power management)";

    tmpfsSize = lib.mkOption {
      type = lib.types.str;
      default = "60%";
      description = "Size of /tmp tmpfs (e.g. '60%')";
    };
  };

  config = lib.mkIf config.modules.profiles.laptop.enable {
    boot.tmp = {
      useTmpfs = true;
      tmpfsSize = config.modules.profiles.laptop.tmpfsSize;
    };

    powerManagement.enable = true;
    # thermald refuses to run on the T14: its DYTC firmware
    # (thinkpad_acpi dytc_lapmode) does thermal management itself, and newer
    # thermald bails on both that and the unrecognized CPU model. The
    # firmware plus TLP cover what thermald did; mkForce beats
    # nixos-hardware's ThinkPad default.
    services.thermald.enable = lib.mkForce false;

    # One power manager: TLP (nixos-hardware's laptop profile enables it; made
    # explicit here). auto-cpufreq used to run alongside it and the two fought
    # over the same governor/EPP knobs. Battery settings measured on the T14
    # (2026-09-03): the defaults left the CPU at its 800 MHz floor during
    # bursts (app launches took ~750 ms, animations dropped frames) and the
    # iGPU at 300 MHz. balance_performance ramps the CPU immediately
    # (launches ~150 ms), the 600 MHz GPU floor keeps compositing smooth, and
    # dynamic boost lets cores turbo briefly on wake-ups. Idle draw is
    # unchanged; mixed-use battery life drops modestly (~5-10%).
    services.tlp = {
      enable = true;
      settings = {
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance";
        CPU_HWP_DYN_BOOST_ON_BAT = 1;
        INTEL_GPU_POWER_PROFILE_ON_BAT = "base";
        INTEL_GPU_MIN_FREQ_ON_BAT = 600;
      };
    };
  };
}
