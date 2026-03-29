{ config, lib, pkgs, ... }:
{
  options.modules.docker.enable = lib.mkEnableOption "Docker container runtime";

  config = lib.mkIf config.modules.docker.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    users.users.justin.extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [
      docker-compose
    ];
  };
}
