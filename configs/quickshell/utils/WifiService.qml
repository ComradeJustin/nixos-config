import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    // ── Status (for bar display) ──
    property string iface: ""
    property string ssid: ""
    property int signal: -1
    property bool connected: false
    property bool enabled: true

    // ── Network list (for CC wifi tab) ──
    property var networks: ListModel {}

    Component.onCompleted: statusProc.running = true

    // ── Quick status poll (bar) ──
    Process {
        id: statusProc
        command: [
            "bash", "-c",
            "if nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected$'; then " +
            "  echo ethernet; " +
            "else " +
            "  line=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -1); " +
            "  ssid=$(echo \"$line\" | cut -d: -f2); " +
            "  sig=$(echo \"$line\" | cut -d: -f3); " +
            "  if [ -n \"$ssid\" ]; then " +
            "    echo \"wifi:$ssid:$sig\"; " +
            "  else " +
            "    echo off; " +
            "  fi; " +
            "fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (data === "ethernet") {
                    root.iface = "ethernet";
                    root.connected = true;
                    root.ssid = "";
                    root.signal = -1;
                } else if (data.indexOf("wifi:") === 0) {
                    var parts = data.split(":");
                    var s = parts[1] || "";
                    if (s.length === 0) {
                        root.iface = "";
                        root.connected = false;
                        root.ssid = "";
                        root.signal = -1;
                    } else {
                        root.iface = "wifi";
                        root.connected = true;
                        root.ssid = s;
                        root.signal = parseInt(parts[2]) || 0;
                    }
                } else {
                    root.iface = "";
                    root.connected = false;
                    root.ssid = "";
                    root.signal = -1;
                }
            }
        }

        onExited: statusPoll.start()
    }

    Timer {
        id: statusPoll
        interval: 10000
        onTriggered: statusProc.running = true
    }

    // ── Full scan (CC wifi tab) ──
    function scan() { scanProc.running = true; }

    Process {
        id: scanProc
        // Deduplicate by SSID in awk: keep first occurrence (active or strongest signal after sort)
        command: [
            "bash", "-c",
            "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | " +
            "awk -F: '$2!=\"\" {printf \"%s\\t%s\\t%s\\t%s\\n\",$1,$2,$3,$4}' | " +
            "sort -t'	' -k1,1r -k3,3nr | " +
            "awk -F'\\t' '!seen[$2]++ {print}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var p = data.split("\t");
                if (p.length < 4) return;
                var isActive = p[0] === "yes";
                root.networks.append({
                    "wifiActive": isActive,
                    "wifiSsid": p[1],
                    "wifiSignal": parseInt(p[2]) || 0,
                    "wifiSecurity": p[3] || ""
                });
                if (isActive) {
                    root.ssid = p[1];
                    root.connected = true;
                }
            }
        }
        onStarted: {
            root.networks.clear();
        }
    }

    // ── Actions ──
    function connectTo(networkSsid) {
        connProc.ssid = networkSsid;
        connProc.running = true;
        refreshAfter.start();
    }

    function disconnect() {
        discProc.running = true;
        refreshAfter.start();
    }

    function toggle() {
        root.enabled = !root.enabled;
        toggleProc.on = root.enabled;
        toggleProc.running = true;
        if (!root.enabled) root.connected = false;
        refreshAfter.start();
    }

    Process { id: connProc; property string ssid: ""; command: ["nmcli", "dev", "wifi", "connect", ssid] }
    Process { id: discProc; command: ["nmcli", "dev", "disconnect", "wlan0"] }
    Process { id: toggleProc; property bool on: true; command: ["nmcli", "radio", "wifi", on ? "on" : "off"] }

    Timer {
        id: refreshAfter
        interval: 3000
        onTriggered: { scanProc.running = true; statusProc.running = true; }
    }
}
