import QtQuick
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: hasBattery ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight
    visible: hasBattery

    // Theme is now a singleton - access via Root.Theme.propertyName

    property string device: "BAT0"
    property int capacity: -1
    property bool charging: false
    property bool pluggedIn: false
    property bool hasBattery: false

    property color activeColor: root.pluggedIn
        ? Root.Theme.textCharging
        : (root.capacity >= 0 && root.capacity <= 15
           ? Root.Theme.textCritical : Root.Theme.textPrimary)

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: {
                if (root.capacity < 0) return Root.Theme.iconBatNone;
                if (root.charging)            return Root.Theme.iconBatChg;
                if (root.capacity > 80)       return Root.Theme.iconBat100;
                if (root.capacity > 60)       return Root.Theme.iconBat80;
                if (root.capacity > 40)       return Root.Theme.iconBat60;
                if (root.capacity > 20)       return Root.Theme.iconBat40;
                return Root.Theme.iconBat20;
            }
            color: root.activeColor
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.capacity >= 0 ? "Bat " + root.capacity + "%" : "Bat --"
            color: root.activeColor
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: Root.Theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.pluggedIn && !root.charging
            text: Root.Theme.iconPlug
            color: Root.Theme.textCharging
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
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
