import QtQuick
import ".." as Root
import "../components" as Components

// Background system stats widget with CPU and RAM usage
Components.WidgetFrame {
    id: root
    widgetName: "system"

    property bool showCpu: true
    property bool showRam: true
    property int fontSize: 24

    property var statsService: null

    // System state — bound to shared service
    property int cpuPercent: statsService ? statsService.cpuPercent : 0
    property real ramUsedGb: statsService ? statsService.ramUsedGb : -1
    property real ramTotalGb: statsService ? statsService.ramTotalGb : -1
    property int ramPercent: ramTotalGb > 0 ? Math.round(ramUsedGb / ramTotalGb * 100) : -1

    Column {
        spacing: 8

        Row {
            visible: root.showCpu
            spacing: 8
            Text {
                text: Root.Theme.iconCpu
                color: root.cpuPercent >= 90 ? Root.Theme.textCritical : Root.Theme.widgetText
                font { family: Root.Theme.fontIcons; pixelSize: root.fontSize }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.cpuPercent + "%"
                color: root.cpuPercent >= 90 ? Root.Theme.textCritical : Root.Theme.widgetText
                font { family: Root.Theme.fontMono; pixelSize: root.fontSize; bold: true }
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            visible: root.showRam
            spacing: 8
            Text {
                text: Root.Theme.iconRam
                color: root.ramPercent >= 90 ? Root.Theme.textCritical : Root.Theme.widgetText
                font { family: Root.Theme.fontIcons; pixelSize: root.fontSize }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.ramUsedGb >= 0 ? root.ramUsedGb.toFixed(1) + "G" : "--"
                color: root.ramPercent >= 90 ? Root.Theme.textCritical : Root.Theme.widgetText
                font { family: Root.Theme.fontMono; pixelSize: root.fontSize; bold: true }
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
