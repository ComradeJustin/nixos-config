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

    Text {
        text: Root.Theme.iconCpu
        color: root.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.domainSystem
        font: root.iconFont
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        text: root.cpuPercent >= 0 ? root.cpuPercent + "%" : "--"
        color: root.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.domainSystem
        font: root.valueFont
        anchors.verticalCenter: parent.verticalCenter
    }
    Item { width: 4; height: 1 }
    Text {
        text: Root.Theme.iconRam
        color: Root.Theme.domainSystem
        font: root.iconFont
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        text: root.ramUsedGb >= 0 ? root.ramUsedGb.toFixed(1) + "G" : "--"
        color: Root.Theme.domainSystem
        font: root.valueFont
        anchors.verticalCenter: parent.verticalCenter
    }
}
