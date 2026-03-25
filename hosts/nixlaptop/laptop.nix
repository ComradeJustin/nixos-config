{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # tmpfs for /tmp — builds happen in RAM
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "60%";  # ~19GB of 32GB
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
    turbo = "never";
    energy_performance_preference = "balance_power";
  };
  charger = {
    governor = "performance";
    turbo = "auto";
    energy_performance_preference = "balance_power";
  };
};
}
