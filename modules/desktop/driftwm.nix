# driftwm: a trackpad-first infinite canvas compositor, installed beside niri.
# The greeter still starts niri until driftwm is picked as the session.
{ inputs, ... }:
{
  imports = [ inputs.driftwm.nixosModules.default ];

  programs.driftwm.enable = true;
}
