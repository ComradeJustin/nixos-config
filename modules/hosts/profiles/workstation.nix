{ config, lib, ... }:
{
  options.modules.hosts.workstation.enable = lib.mkEnableOption "workstation profile (future: performance tuning)";

  config = lib.mkIf config.modules.hosts.workstation.enable {
    # Future: CPU governor, IO scheduler, etc.
  };
}
