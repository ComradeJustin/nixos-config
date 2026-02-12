{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # fingerprint reader

  environment.systemPackages = with pkgs; [
    fprintd
  ];
  services.fprintd.enable = true;
  services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix-550a;
  
  security.pam.services = {
    login.fprintAuth = true;
    sudo.fprintAuth = true;
    polkit.fprintAuth = true;
    
  };

}
