import QtQuick
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: hasBattery ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight
    visible: hasBattery

    Root.Theme { id: theme }

    property string device: "BAT0"
    property int capacity: -1
    property bool charging: false
    property bool pluggedIn: false
    property bool hasBattery: false

    property color activeColor: root.pluggedIn
        ? theme.textCharging
        : (root.capacity >= 0 && root.capacity <= 15
           ? theme.textCritical : theme.textPrimary)

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

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

        Text {
            text: root.capacity >= 0 ? "BAT " + root.capacity + "%" : "BAT --"
            color: root.activeColor
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.pluggedIn && !root.charging
            text: theme.iconPlug
            color: theme.textCharging
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Check if battery device exists
    Process {
        id: detectProc
        command: ["test", "-d", "/sys/class/power_supply/" + root.device]
        running: true
        onExited: function(exitCode) {
            root.hasBattery = (exitCode === 0);
            if (root.hasBattery) {
                capProc.running = true;
                statusProc.running = true;
            }
        }
    }

    Process {
        id: capProc
        command: ["cat", "/sys/class/power_supply/" + root.device + "/capacity"]

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
            if (root.hasBattery) {
                capProc.running = true;
                statusProc.running = true;
            }
        }
    }
}
