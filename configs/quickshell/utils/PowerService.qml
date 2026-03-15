import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    function lock() { lockProc.running = true; }
    function suspend() { suspendProc.running = true; }
    function reboot() { rebootProc.running = true; }
    function shutdown() { shutdownProc.running = true; }
    function logout() { logoutProc.running = true; }

    Process { id: lockProc; command: ["loginctl", "lock-session"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    Process { id: logoutProc; command: ["niri", "msg", "action", "quit"] }
}
