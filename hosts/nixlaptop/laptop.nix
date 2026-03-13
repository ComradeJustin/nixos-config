{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  powerManagement.enable = true;
  services.thermald.enable = true;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
  battery = {
    governor = "powersave";
    turbo = "auto";
  };
  charger = {
    governor = "performance";
    turbo = "never";
  };
};
}
