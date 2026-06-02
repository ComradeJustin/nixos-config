import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root
    custom: true

    property var svc: Core.ServiceManager.systemStats
    property int cpuPercent: svc ? svc.cpuPercent : -1
    property real ramUsedGb: svc ? svc.ramUsedGb : -1
    property real ramTotalGb: svc ? svc.ramTotalGb : -1
    property int ramPercent: svc ? svc.ramPercent : -1
    property real diskUsedGb: svc ? svc.diskUsedGb : -1
    property real diskTotalGb: svc ? svc.diskTotalGb : -1
    property int diskPercent: svc ? svc.diskPercent : -1
    property string uptime: svc ? svc.uptime : ""

    // Mini CPU sparkline graph (toggleable) — reads history from the
    // service so it survives bar feature toggles and config reloads.
    Components.Graph {
        visible: Root.Config.bar.showCpuGraph
        width: visible ? 32 : 0; height: 14
        anchors.verticalCenter: parent.verticalCenter
        values: root.svc ? root.svc.cpuHistory : []
        lineColor: root.cpuPercent >= 90
            ? Root.Theme.accentDanger
            : Root.Theme.domainSystem
        lineWidth: 1
    }

    Text {
        text: Root.Icons.cpu
        color: root.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.domainSystem
        font: root.iconFont
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        text: root.cpuPercent >= 0 ? root.cpuPercent + "%" : "--"
        color: root.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.textPrimary
        font: root.valueFont
        anchors.verticalCenter: parent.verticalCenter
    }
    Item { width: 4; height: 1 }

    // Mini RAM sparkline graph (toggleable)
    Components.Graph {
        visible: Root.Config.bar.showCpuGraph
        width: visible ? 32 : 0; height: 14
        anchors.verticalCenter: parent.verticalCenter
        values: root.svc ? root.svc.ramHistory : []
        lineColor: root.ramPercent >= 90
            ? Root.Theme.accentDanger
            : Root.Theme.domainSystem
        lineWidth: 1
        fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.10)
    }

    Text {
        text: Root.Icons.ram
        color: Root.Theme.domainSystem
        font: root.iconFont
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        text: root.ramUsedGb >= 0 ? root.ramUsedGb.toFixed(1) + "G" : "--"
        color: Root.Theme.textPrimary
        font: root.valueFont
        anchors.verticalCenter: parent.verticalCenter
    }

}
