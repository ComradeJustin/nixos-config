{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.fabric;
  run-widget = inputs.fabric.packages.${pkgs.system}.run-widget;
  # Same live-edit path as the v2 QML overlay. Rebuild only when the
  # Fabric package itself changes.
  configDir = "/home/justin/nixos-config/configs/fabric";
in
{
  options.modules.fabric.enable = lib.mkEnableOption "Fabric overlay (Python/GTK)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.glib
      run-widget
      (pkgs.writeShellScriptBin "fabric-shell" ''
        # Cache bytecode outside the repo rather than disabling it; recompiling
        # every module on each start costs real launch time.
        export PYTHONPYCACHEPREFIX="$HOME/.cache/fabric/pycache"
        exec ${lib.getExe run-widget} ${configDir}/main.py
      '')
      (pkgs.writeShellScriptBin "fabric-toggle" ''
        exec ${lib.getBin pkgs.glib}/bin/gdbus call --session \
          --dest org.Fabric.fabric.shell \
          --object-path /org/Fabric/fabric \
          --method org.Fabric.fabric.InvokeAction \
          toggle "[]"
      '')
    ];
  };
}
