{ config, lib, pkgs, ... }:
let
  cfg = config.modules.wayvnc;
in
{
  options.modules.wayvnc = {
    enable = lib.mkEnableOption "wayvnc VNC server attached to the running Wayland session";

    output = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Wayland output to capture at startup (empty = compositor default).
        Switch live at runtime with:
          XDG_RUNTIME_DIR=/run/user/$(id -u) wayvncctl output-set <name>
      '';
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address. Keep it on localhost and reach it over an SSH tunnel — do NOT expose VNC to the network.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5900;
      description = "TCP port for the VNC server (localhost only).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.wayvnc ];

    # Runs inside the user's graphical (niri) session so it can screencopy the
    # live outputs. Bound to localhost; access is via `ssh -L ${toString cfg.port}:127.0.0.1:${toString cfg.port}`.
    systemd.user.services.wayvnc = {
      description = "wayvnc VNC server (localhost — reach via SSH tunnel)";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart =
          "${pkgs.wayvnc}/bin/wayvnc"
          + lib.optionalString (cfg.output != "") " -o ${cfg.output}"
          + " ${cfg.address} ${toString cfg.port}";
        # Outputs may not exist the instant graphical-session.target is reached;
        # retry until the compositor is fully up.
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
