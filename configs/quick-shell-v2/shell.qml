//@ pragma UseQApplication
//@ pragma IconTheme Gruvbox-Plus-Dark
import Quickshell
import Quickshell.Io
import QtQuick
import "." as Root

// v2 shell: vim launcher only. The current bar stays in the old
// quickshell process. Mod+Space talks to this process.
ShellRoot {
    Root.Command {
        id: launcher
    }

    IpcHandler {
        target: "quickshell-v2"

        function toggle(): string {
            launcher.toggle();
            return "ok";
        }

        function open(): string {
            launcher.open();
            return "ok";
        }

        function close(): string {
            launcher.close();
            return "ok";
        }
    }
}
