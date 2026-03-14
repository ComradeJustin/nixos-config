import Quickshell
import Quickshell.Io
import "modules" as Modules

ShellRoot {
    Modules.Notifications { id: notifModule }
    Modules.Spotlight { id: spotModule }
    Modules.Osd {}
    Modules.Bar { notifRef: notifModule }

    // ── IPC handler for keybind-triggered popups ──
    // In niri config.kdl:
    //   Mod+D { spawn "qs" "-p" "/path/to/config" "ipc" "call" "quickshell-bar" "launcher"; }
    //   Mod+V { spawn "qs" "-p" "/path/to/config" "ipc" "call" "quickshell-bar" "clipboard"; }
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
    }
}
