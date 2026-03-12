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

    property color activeColor: root.pluggedIn
        ? theme.textCharging
        : (root.capacity >= 0 && root.capacity <= 15
           ? theme.textCritical : theme.textPrimary)

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        // ── Battery icon ──
        Text {
            text: {
                if (root.capacity < 0) return theme.iconBatNone;
                if (root.charging)            return theme.iconBatChg;
                if (root.capacity > 80)       return theme.iconBat100;
                if (root.capacity > 60)       return theme.iconBat80;
                if (root.capacity > 40)       return theme.iconBat60;
                if (root.capacity > 20)       return theme.iconBat40;
                return theme.iconBat20;
            }
            color: root.activeColor
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── Percentage ──
        Text {
            text: root.capacity >= 0 ? root.capacity + "%" : "--"
            color: root.activeColor
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── Plug indicator (only when plugged in, not actively charging) ──
        Text {
            visible: root.pluggedIn && !root.charging
            text: theme.iconPlug
            color: theme.textCharging
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
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
