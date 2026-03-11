import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property string device: "BAT0"
    property int capacity: -1
    property bool charging: false
    property bool pluggedIn: false

    Row {
        id: row
        spacing: 4

        Text {
            text: {
                if (root.capacity < 0) return theme.iconBatNone + " --";
                let icon;
                if (root.charging)            icon = theme.iconBatChg;
                else if (root.capacity > 80)  icon = theme.iconBat100;
                else if (root.capacity > 60)  icon = theme.iconBat80;
                else if (root.capacity > 40)  icon = theme.iconBat60;
                else if (root.capacity > 20)  icon = theme.iconBat40;
                else                          icon = theme.iconBat20;
                let label = icon + " " + root.capacity + "%";
                if (root.charging) label += " ⚡";
                else if (root.pluggedIn) label += " " + theme.iconPlug;
                return label;
            }
            color: root.pluggedIn
                   ? theme.textCharging
                   : (root.capacity >= 0 && root.capacity <= 15
                      ? theme.textCritical : theme.textPrimary)
            font {
                family: theme.fontFamily
                pixelSize: theme.fontSize
                bold: theme.fontBold
            }
        }
    }

    Process {
        id: capProc
        command: ["cat", "/sys/class/power_supply/" + root.device + "/capacity"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let val = parseInt(data);
                if (!isNaN(val)) root.capacity = val;
            }
        }

        onExited: pollTimer.start()
    }

    Process {
        id: statusProc
        command: ["cat", "/sys/class/power_supply/" + root.device + "/status"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                root.charging = (data === "Charging");
                root.pluggedIn = (data === "Charging" || data === "Not charging" || data === "Full");
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 5000
        onTriggered: {
            capProc.running = true;
            statusProc.running = true;
        }
    }
}
