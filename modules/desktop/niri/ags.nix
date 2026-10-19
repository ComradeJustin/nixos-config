{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.ags;
  agsPackages = inputs.ags.packages.${pkgs.system};
  # The overlay's Astal service libraries plus libadwaita for animations.
  ags = agsPackages.ags.override {
    extraPackages = [
      agsPackages.apps
      agsPackages.network
      agsPackages.bluetooth
      agsPackages.wireplumber
      pkgs.libadwaita
    ];
  };
  # Same live-edit path as the fabric overlay and the QML shell. Rebuild only
  # when the AGS package itself changes.
  configDir = "/home/justin/nixos-config/configs/ags";
  ags-shell = pkgs.writeShellScriptBin "ags-shell" ''
    exec ${lib.getExe ags} run ${configDir}/app.ts "$@"
  '';
in
{
  options.modules.ags.enable = lib.mkEnableOption "AGS overlay shell (TypeScript/GTK4)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      ags
      ags-shell
      (pkgs.writeShellScriptBin "ags-toggle" ''
        exec ${lib.getExe ags} request toggle
      '')
    ];

    # Supervised: a crash (e.g. the pango/fontconfig segfault of 2026-09-01)
    # restarts the overlay in seconds instead of leaving Mod+Space dead.
    # Replaces the spawn-at-startup line in startup.kdl.
    systemd.user.services.ags-shell = {
      description = "AGS ring overlay";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      # NixOS pins each unit's PATH to a minimal set; the overlay shells out
      # to session tools (awww, loginctl, niri), so give it the system and
      # per-user profiles too.
      path = [
        "/run/current-system/sw"
        "/etc/profiles/per-user/justin"
      ];
      serviceConfig = {
        ExecStart = "${ags-shell}/bin/ags-shell";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };
}
