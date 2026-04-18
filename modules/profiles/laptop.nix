{ config, lib, pkgs, ... }:
{
  options.modules.profiles.laptop = {
    enable = lib.mkEnableOption "laptop profile (tmpfs, thermald, auto-cpufreq)";

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
    services.thermald = {
      enable = true;
      configFile = pkgs.writeText "thermal-conf.xml" ''
        <?xml version="1.0"?>
        <ThermalConfiguration>
          <ThermalZones>
            <ThermalZone>
              <Type>auto</Type>
              <TripPoints>
                <TripPoint>
                  <SensorType>x86_pkg_temp</SensorType>
                  <Temperature>80000</Temperature>
                  <Type>Passive</Type>
                  <CoolingDevice>
                    <Type>rapl_controller</Type>
                    <influence>100</influence>
                  </CoolingDevice>
                  <CoolingDevice>
                    <Type>intel_pstate</Type>
                    <influence>100</influence>
                  </CoolingDevice>
                </TripPoint>
              </TripPoints>
            </ThermalZone>
          </ThermalZones>
        </ThermalConfiguration>
      '';
    };
    services.auto-cpufreq.enable = true;
    services.auto-cpufreq.settings = {
      battery = {
        governor = "powersave";
        turbo = "auto";
        energy_performance_preference = "balance_power";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
        energy_performance_preference = "balance_power";
      };
    };
  };
}
