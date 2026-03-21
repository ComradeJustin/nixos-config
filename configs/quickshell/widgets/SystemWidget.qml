import QtQuick
import Quickshell.Io
import ".." as Root

// Background system stats widget with CPU and RAM usage
Item {
    id: root

    // Config properties
    property bool showCpu: true
    property bool showRam: true
    property int fontSize: 24

    implicitWidth: content.implicitWidth + Root.Theme.widgetPadding * 2
    implicitHeight: content.implicitHeight + Root.Theme.widgetPadding * 2

    // System state
    property int cpuPercent: 0
    property real ramUsedGb: -1
    property real ramTotalGb: -1
    property int ramPercent: ramTotalGb > 0 ? Math.round(ramUsedGb / ramTotalGb * 100) : -1
    property real prevIdle: 0
    property real prevTotal: 0

    // CPU reading process
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
        onExited: (code) => {
            if (code === 0) {
                ramProc.running = true;
            } else {
                pollTimer.start();
            }
        }
    }

    // RAM reading process
    Process {
        id: ramProc
        command: ["awk", "/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf \"%d %d\", t, a}", "/proc/meminfo"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(/\s+/);
                if (parts.length >= 2) {
                    let totalKb = parseFloat(parts[0]);
                    let availKb = parseFloat(parts[1]);
                    if (totalKb > 0) {
                        root.ramTotalGb = totalKb / 1048576;
                        root.ramUsedGb = (totalKb - availKb) / 1048576;
                    }
                }
            }
        }
        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: Root.Config.systemStatsInterval
        onTriggered: cpuProc.running = true
    }

    // Shadow layer
    Rectangle {
        anchors.fill: bg
        anchors.margins: -2
        anchors.topMargin: 2
        radius: Root.Theme.widgetRadius + 2
        color: Root.Theme.widgetShadowColor
        opacity: 0.4
    }

    // Widget background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Theme.widgetBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 8

        // CPU Row
        Row {
            visible: root.showCpu
            spacing: 8

            Text {
                text: Root.Theme.iconCpu
                color: root.cpuPercent >= 90 ? Root.Theme.textCritical : Root.Theme.widgetText
                font {
                    family: Root.Theme.fontIcons
                    pixelSize: root.fontSize
                }
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.cpuPercent + "%"
                color: root.cpuPercent >= 90 ? Root.Theme.textCritical : Root.Theme.widgetText
                font {
                    family: Root.Theme.fontMono
                    pixelSize: root.fontSize
                    bold: true
                }
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // RAM Row
        Row {
            visible: root.showRam
            spacing: 8

            Text {
                text: Root.Theme.iconRam
                color: root.ramPercent >= 90 ? Root.Theme.textCritical : Root.Theme.widgetText
                font {
                    family: Root.Theme.fontIcons
                    pixelSize: root.fontSize
                }
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.ramUsedGb >= 0 ? root.ramUsedGb.toFixed(1) + "G" : "--"
                color: root.ramPercent >= 90 ? Root.Theme.textCritical : Root.Theme.widgetText
                font {
                    family: Root.Theme.fontMono
                    pixelSize: root.fontSize
                    bold: true
                }
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
