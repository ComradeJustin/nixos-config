import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    // ── Status (for bar display) ──
    property bool enabled: true
    property bool connected: false
    property string connectedDevice: ""
    property string connectedType: ""  // "audio", "input", "other"

    // ── Device list (for CC bluetooth tab) ──
    property var devices: ListModel {}

    // ── Internal state ──
    property bool scanning: false

    Component.onCompleted: statusProc.running = true

    // ── Quick status poll (bar) ──
    Process {
        id: statusProc
        command: [
            "bash", "-c",
            "if ! command -v bluetoothctl &>/dev/null; then echo 'unavailable'; exit; fi; " +
            "powered=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo yes || echo no); " +
            "if [ \"$powered\" = \"no\" ]; then echo 'off'; exit; fi; " +
            "conn=$(bluetoothctl devices Connected 2>/dev/null | head -1); " +
            "if [ -n \"$conn\" ]; then " +
            "  mac=$(echo \"$conn\" | awk '{print $2}'); " +
            "  name=$(echo \"$conn\" | cut -d' ' -f3-); " +
            "  type=$(bluetoothctl info \"$mac\" 2>/dev/null | grep -i 'Icon:' | awk '{print $2}'); " +
            "  echo \"connected:$name:$type\"; " +
            "else " +
            "  echo 'on'; " +
            "fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (data === "unavailable") {
                    root.enabled = false;
                    root.connected = false;
                    root.connectedDevice = "";
                    root.connectedType = "";
                } else if (data === "off") {
                    root.enabled = false;
                    root.connected = false;
                    root.connectedDevice = "";
                    root.connectedType = "";
                } else if (data === "on") {
                    root.enabled = true;
                    root.connected = false;
                    root.connectedDevice = "";
                    root.connectedType = "";
                } else if (data.indexOf("connected:") === 0) {
                    var parts = data.split(":");
                    root.enabled = true;
                    root.connected = true;
                    root.connectedDevice = parts[1] || "";
                    root.connectedType = parts[2] || "other";
                }
            }
        }

        onExited: statusPoll.start()
    }

    Timer {
        id: statusPoll
        interval: 10000  // Poll every 10s (matches WifiService)
        onTriggered: statusProc.running = true
    }

    // ── Full device scan (CC bluetooth tab) ──
    function scan() {
        root.scanning = true;
        scanProc.running = true;
    }

    Process {
        id: scanProc
        command: [
            "bash", "-c",
            "if ! command -v bluetoothctl &>/dev/null; then exit; fi; " +
            // Start discovery briefly
            "bluetoothctl --timeout 3 scan on &>/dev/null & " +
            "sleep 2; " +
            // Get paired devices
            "bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do " +
            "  [ -z \"$mac\" ] && continue; " +
            "  info=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
            "  conn=$(echo \"$info\" | grep -q 'Connected: yes' && echo yes || echo no); " +
            "  type=$(echo \"$info\" | grep -i 'Icon:' | awk '{print $2}'); " +
            "  [ -z \"$type\" ] && type='other'; " +
            "  echo \"paired\t$mac\t$name\t$conn\t$type\"; " +
            "done; " +
            // Get discovered (not paired) devices
            "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do " +
            "  [ -z \"$mac\" ] && continue; " +
            "  bluetoothctl devices Paired 2>/dev/null | grep -q \"$mac\" && continue; " +
            "  info=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
            "  type=$(echo \"$info\" | grep -i 'Icon:' | awk '{print $2}'); " +
            "  [ -z \"$type\" ] && type='other'; " +
            "  echo \"discovered\t$mac\t$name\tno\t$type\"; " +
            "done"
        ]

        stdout: SplitParser {
            onRead: data => {
                var p = data.split("\t");
                if (p.length < 5) return;
                root.devices.append({
                    "btPaired": p[0] === "paired",
                    "btMac": p[1],
                    "btName": p[2],
                    "btConnected": p[3] === "yes",
                    "btType": p[4]
                });
            }
        }

        onStarted: {
            root.devices.clear();
        }

        onExited: {
            root.scanning = false;
        }
    }

    // ── Actions ──
    function toggle() {
        root.enabled = !root.enabled;
        toggleProc.on = root.enabled;
        toggleProc.running = true;
        if (!root.enabled) {
            root.connected = false;
            root.connectedDevice = "";
        }
        refreshAfter.start();
    }

    function connect(mac) {
        connProc.mac = mac;
        connProc.running = true;
        refreshAfter.start();
    }

    function disconnect(mac) {
        discProc.mac = mac;
        discProc.running = true;
        refreshAfter.start();
    }

    function pair(mac) {
        pairProc.mac = mac;
        pairProc.running = true;
        refreshAfter.start();
    }

    function remove(mac) {
        removeProc.mac = mac;
        removeProc.running = true;
        refreshAfter.start();
    }

    Process {
        id: toggleProc
        property bool on: true
        command: ["bluetoothctl", "power", on ? "on" : "off"]
    }

    Process {
        id: connProc
        property string mac: ""
        command: ["bluetoothctl", "connect", mac]
    }

    Process {
        id: discProc
        property string mac: ""
        command: ["bluetoothctl", "disconnect", mac]
    }

    Process {
        id: pairProc
        property string mac: ""
        command: ["sh", "-c", "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\"", "--", mac]
    }

    Process {
        id: removeProc
        property string mac: ""
        command: ["bluetoothctl", "remove", mac]
    }

    Timer {
        id: refreshAfter
        interval: 2000
        onTriggered: { scanProc.running = true; statusProc.running = true; }
    }
}
