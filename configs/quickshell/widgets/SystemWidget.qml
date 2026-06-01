import QtQuick
import ".." as Root
import "../components" as Components
import "../core" as Core

// Background system stats widget with CPU and RAM usage
Components.WidgetFrame {
    id: root
    widgetName: "system"

    property bool showCpu: Root.Config.systemConfig.showCpu
    property bool showRam: Root.Config.systemConfig.showRam
    property int fontSize: Root.Config.systemConfig.fontSize

    property var statsService: Core.ServiceManager.systemStats

    // System state — bound to shared service
    property int cpuPercent: statsService ? statsService.cpuPercent : 0
    property real ramUsedGb: statsService ? statsService.ramUsedGb : -1
    property real ramTotalGb: statsService ? statsService.ramTotalGb : -1
    property int ramPercent: ramTotalGb > 0 ? Math.round(ramUsedGb / ramTotalGb * 100) : -1

    Column {
        spacing: Root.Theme.spacingS

        Row {
            visible: root.showCpu
            spacing: Root.Theme.spacingS
            Text {
                text: Root.Icons.cpu
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
            spacing: Root.Theme.spacingS
            Text {
                text: Root.Icons.ram
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
