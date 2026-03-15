import Quickshell
import Quickshell.Io
import "modules" as Modules
import "utils" as Utils

ShellRoot {
    Utils.AudioService { id: audioSvc }
    Utils.PlayerService { id: playerSvc }
    Utils.PowerService { id: powerSvc }
    Utils.NotifService { id: notifSvc }

    Modules.PowerMenu { id: pmModule; powerService: powerSvc }
    Modules.ControlCenter { id: ccModule; audioService: audioSvc; powerMenuRef: pmModule; notifService: notifSvc }
    Modules.Spotlight { id: spotModule }
    Modules.Osd {}
    Modules.Bar {
        notifRef: ccModule
        playerService: playerSvc
        powerService: powerSvc
        audioService: audioSvc
        powerMenuRef: pmModule
    }

    IpcHandler {
        target: "quickshell-bar"

        function launcher(): string { spotModule.toggle("launcher"); return "ok"; }
        function clipboard(): string { spotModule.toggle("clipboard"); return "ok"; }
        function wallpaper(): string { spotModule.toggle("wallpaper"); return "ok"; }
        function controlcenter(): string { ccModule.toggle(); return "ok"; }
        function powermenu(): string { pmModule.toggle(); return "ok"; }
    }
}
