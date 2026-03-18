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
    property bool hasScanned: false  // Track if we've done initial scan

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

    // ── Device scan (CC bluetooth tab) - Only paired devices ──
    function scan(force) {
        // Don't rescan if we already have data, unless forced
        if (root.hasScanned && !force && root.devices.count > 0) return;
        root.scanning = true;
        scanProc.running = true;
    }

    // Internal property to collect all output before parsing
    property string scanBuffer: ""

    Process {
        id: scanProc
        command: [
            "bash", "-c",
            "if ! command -v bluetoothctl &>/dev/null; then exit; fi; " +
            // Only get PAIRED devices - no discovery scan needed
            "bluetoothctl devices Paired 2>/dev/null | while IFS= read -r line; do " +
            "  mac=$(echo \"$line\" | awk '{print $2}'); " +
            "  [ -z \"$mac\" ] && continue; " +
            // Get the name from bluetoothctl info (more reliable than devices output)
            "  info=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
            "  name=$(echo \"$info\" | grep -m1 'Name:' | cut -d: -f2- | sed 's/^[[:space:]]*//'); " +
            // Fallback to device list name if info doesn't have it
            "  [ -z \"$name\" ] && name=$(echo \"$line\" | cut -d' ' -f3-); " +
            "  conn=$(echo \"$info\" | grep -q 'Connected: yes' && echo yes || echo no); " +
            "  type=$(echo \"$info\" | grep -i 'Icon:' | awk '{print $2}'); " +
            "  [ -z \"$type\" ] && type='other'; " +
            "  echo \"$mac\t$name\t$conn\t$type\"; " +
            "done"
        ]

        onStarted: {
            root.scanBuffer = "";
        }

        stdout: SplitParser {
            onRead: data => {
                // Collect all lines into buffer
                root.scanBuffer += data + "\n";
            }
        }

        onExited: {
            // Parse all devices at once for instant UI update
            root.devices.clear();
            var lines = root.scanBuffer.trim().split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.length === 0) continue;
                var p = line.split("\t");
                if (p.length < 4) continue;
                root.devices.append({
                    "btPaired": true,
                    "btMac": p[0],
                    "btName": p[1] || p[0],  // Fallback to MAC if name empty
                    "btConnected": p[2] === "yes",
                    "btType": p[3]
                });
            }
            root.scanning = false;
            root.hasScanned = true;
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
        onTriggered: {
            root.hasScanned = false;  // Force rescan after actions
            scanProc.running = true;
            statusProc.running = true;
        }
    }
}
