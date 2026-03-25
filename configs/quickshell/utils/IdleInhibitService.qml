import Quickshell
import Quickshell.Io
import QtQuick

// Manual idle inhibitor (caffeine mode) using systemd-inhibit
Scope {
    id: root

    property bool inhibited: false

    function toggle() {
        if (inhibited) disable();
        else enable();
    }

    function enable() {
        if (root.inhibited) return;
        root.inhibited = true;
        inhibitProc.running = true;
    }

    function disable() {
        if (!root.inhibited) return;
        root.inhibited = false;
        // Kill the sleep process inside the inhibit to release the lock
        killProc.running = true;
    }

    // systemd-inhibit holds the idle lock as long as the child process runs
    Process {
        id: inhibitProc
        command: [
            "systemd-inhibit",
            "--what=idle",
            "--who=QuickShell Caffeine",
            "--why=User requested idle inhibition",
            "--mode=block",
            "sleep", "infinity"
        ]
        onExited: {
            root.inhibited = false;
        }
    }

    // Kill any sleep infinity spawned by our inhibitor
    Process {
        id: killProc
        command: ["bash", "-c", "pkill -f 'systemd-inhibit --what=idle.*QuickShell Caffeine'"]
    }
}
