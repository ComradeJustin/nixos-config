import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root
    custom: true
    popupContent: resPopup

    property var svc: Core.ServiceManager.systemStats
    property int cpuPercent: svc ? svc.cpuPercent : -1
    property real ramUsedGb: svc ? svc.ramUsedGb : -1
    property real ramTotalGb: svc ? svc.ramTotalGb : -1
    property int ramPercent: svc ? svc.ramPercent : -1
    property real diskUsedGb: svc ? svc.diskUsedGb : -1
    property real diskTotalGb: svc ? svc.diskTotalGb : -1
    property int diskPercent: svc ? svc.diskPercent : -1
    property string uptime: svc ? svc.uptime : ""

    // CPU history for mini graph
    property var cpuHistory: []
    property int historyMax: 20

    onCpuPercentChanged: {
        if (cpuPercent < 0) return;
        let h = cpuHistory.slice();
        h.push(cpuPercent / 100);
        if (h.length > historyMax) h.shift();
        cpuHistory = h;
    }

    // Mini CPU sparkline graph (toggleable)
    Components.Graph {
        visible: Root.Config.bar.showCpuGraph
        width: visible ? 32 : 0; height: 14
        anchors.verticalCenter: parent.verticalCenter
        values: root.cpuHistory
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

    // ── Popup content (hosted in shared BarPopup window) ──
    property Components.HoverPopup resPopup: Components.HoverPopup {
        popupWidth: 200

        Text {
            text: "System Resources"
            color: Root.Theme.domainSystem
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; bold: true }
            width: parent ? parent.width : 0
        }

        Rectangle {
            width: parent ? parent.width : 0; height: 1
            color: Root.Theme.borderColor; opacity: 0.5
        }

        Components.PopupRow {
            label: "CPU"
            value: root.cpuPercent >= 0 ? root.cpuPercent + "%" : "--"
            valueColor: root.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.textPrimary
        }

        Components.PopupRow {
            label: "RAM"
            value: root.ramUsedGb >= 0
                ? root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
                : "--"
            valueColor: root.ramPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.textPrimary
        }

        Rectangle {
            width: parent ? parent.width : 0; height: 4
            radius: 2; color: Root.Theme.layer1
            Rectangle {
                width: root.ramPercent > 0 ? parent.width * root.ramPercent / 100 : 0
                height: parent.height; radius: 2
                color: root.ramPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.domainSystem
                Behavior on width { NumberAnimation { duration: Root.Theme.anim.moveDuration } }
            }
        }

        Components.PopupRow {
            label: "Disk (/)"
            value: root.diskUsedGb >= 0
                ? root.diskUsedGb.toFixed(0) + " / " + root.diskTotalGb.toFixed(0) + " GB"
                : "--"
            valueColor: root.diskPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.textPrimary
        }

        Rectangle {
            width: parent ? parent.width : 0; height: 4
            radius: 2; color: Root.Theme.layer1
            Rectangle {
                width: root.diskPercent > 0 ? parent.width * root.diskPercent / 100 : 0
                height: parent.height; radius: 2
                color: root.diskPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.accentPrimary
                Behavior on width { NumberAnimation { duration: Root.Theme.anim.moveDuration } }
            }
        }

        Components.PopupRow {
            label: "Uptime"
            value: root.uptime || "--"
        }
    }
}
