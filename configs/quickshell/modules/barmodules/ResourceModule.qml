import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    property int cpuPercent: -1
    property real ramUsedGb: -1
    property real ramTotalGb: -1
    property real prevIdle: 0
    property real prevTotal: 0

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: Root.Theme.iconCpu
            color: root.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.domainSystem
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.cpuPercent >= 0 ? root.cpuPercent + "%" : "--"
            color: root.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.domainSystem
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
            anchors.verticalCenter: parent.verticalCenter
        }

        Item { width: 4; height: 1 }

        Text {
            text: Root.Theme.iconRam
            color: Root.Theme.domainSystem
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.ramUsedGb >= 0 ? root.ramUsedGb.toFixed(1) + "G" : "--"
            color: Root.Theme.domainSystem
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Process {
        id: cpuProc
        command: ["head", "-1", "/proc/stat"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(/\s+/);
                if (parts.length < 5) return;

                let idle = parseFloat(parts[4]) + (parseFloat(parts[5]) || 0);
                let total = 0;
                for (let i = 1; i < parts.length; i++)
                    total += parseFloat(parts[i]) || 0;

                let dIdle = idle - root.prevIdle;
                let dTotal = total - root.prevTotal;

                if (root.prevTotal > 0 && dTotal > 0)
                    root.cpuPercent = Math.round(100 * (1 - dIdle / dTotal));

                root.prevIdle = idle;
                root.prevTotal = total;
            }
        }

        onExited: ramProc.running = true
    }

    Process {
        id: ramProc
        command: [
            "bash", "-c",
            "awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf \"%d %d\", t, a}' /proc/meminfo"
        ]

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(/\s+/);
                if (parts.length >= 2) {
                    let totalKb = parseFloat(parts[0]);
                    let availKb = parseFloat(parts[1]);
                    if (totalKb > 0) {
                        root.ramTotalGb = totalKb / 1048576;
                        root.ramUsedGb  = (totalKb - availKb) / 1048576;
                    }
                }
            }
        }

        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: 3000
        onTriggered: cpuProc.running = true
    }
}
