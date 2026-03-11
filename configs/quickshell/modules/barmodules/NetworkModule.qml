import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property string iface: ""
    property string ssid: ""
    property int signal: -1
    property bool connected: false

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: {
                if (!root.connected) return theme.iconWifiOff;
                if (root.iface === "ethernet") return theme.iconEth;
                if (root.signal > 75)  return theme.iconWifiHi;
                if (root.signal > 50)  return theme.iconWifiMid;
                if (root.signal > 25)  return theme.iconWifiLow;
                return theme.iconWifiMin;
            }
            color: root.connected ? theme.textPrimary : theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                if (!root.connected) return "off";
                if (root.iface === "ethernet") return "eth";
                return root.ssid;
            }
            color: root.connected ? theme.textPrimary : theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Process {
        id: proc
        command: [
            "bash", "-c",
            "if nmcli -t -f TYPE,STATE dev | grep -q '^ethernet:connected$'; then " +
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
                } else if (data.startsWith("wifi:")) {
                    let parts = data.split(":");
                    let ssid = parts[1] || "";
                    if (ssid.length === 0) {
                        root.iface = "";
                        root.connected = false;
                        root.ssid = "";
                        root.signal = -1;
                    } else {
                        root.iface = "wifi";
                        root.connected = true;
                        root.ssid = ssid;
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

        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: 10000
        onTriggered: proc.running = true
    }
}
