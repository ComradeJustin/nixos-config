import Quickshell
import Quickshell.Io
import "modules" as Modules

ShellRoot {
    Modules.ControlCenter { id: ccModule }
    Modules.Spotlight { id: spotModule }
    Modules.Osd {}
    Modules.Bar { notifRef: ccModule }

    IpcHandler {
        target: "quickshell-bar"

        function launcher(): string {
            spotModule.toggle("launcher");
            return "ok";
        }

        function clipboard(): string {
            spotModule.toggle("clipboard");
            return "ok";
        }

        function wallpaper(): string {
            spotModule.toggle("wallpaper");
            return "ok";
        }

        function controlcenter(): string {
            ccModule.toggle();
            return "ok";
        }
    }
}
