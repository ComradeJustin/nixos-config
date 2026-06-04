import QtQuick
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// SystemMonitorCard — CPU, memory, and disk at a glance.
// Flat design: a section header (accent icon + title), then one row per metric
// with an uppercase label, a right-aligned mono value, and a thin flat bar.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: body.implicitHeight + Root.Theme.spacingM * 2

    readonly property var svc: Core.ServiceManager.systemStats

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // One metric: uppercase label + right-aligned mono value, thin flat bar below.
    component Metric: Column {
        id: m
        property string label: ""
        property string value: ""
        property real fraction: 0
        property color barColor: Root.Theme.domainSystem
        spacing: 4

        Item {
            width: parent.width
            height: lbl.implicitHeight

            Text {
                id: lbl
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: m.label
                color: Root.Theme.textDimmed
                font {
                    family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS; bold: true
                    capitalization: Font.AllUppercase; letterSpacing: Root.Theme.trackingCaps
                }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: m.value
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeS }
            }
        }

        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Root.Theme.layer2

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, m.fraction))
                height: parent.height
                radius: parent.radius
                color: m.barColor
                Behavior on width { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
            }
        }
    }

    // Flat accent strip
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: Root.Theme.domainSystem
    }

    Column {
        id: body
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: Root.Theme.spacingM + 3
            rightMargin: Root.Theme.spacingM
            topMargin: Root.Theme.spacingM
        }
        spacing: Root.Theme.spacingM

        // ── Section header ──
        Components.CCCardHeader {
            width: parent.width
            icon: Root.Icons.monitor
            title: "System"
            accent: Root.Theme.domainSystem
        }

        // ── Metrics ──
        Column {
            width: parent.width
            spacing: Root.Theme.spacingS

            Metric {
                width: parent.width
                label: "CPU"
                value: card.svc && card.svc.cpuPercent >= 0 ? card.svc.cpuPercent + "%" : "--"
                fraction: card.svc ? card.svc.cpuPercent / 100 : 0
                barColor: Root.Theme.base0B
            }
            Metric {
                width: parent.width
                label: "Memory"
                value: card.svc && card.svc.ramUsedGb >= 0
                    ? card.svc.ramUsedGb.toFixed(1) + " / " + card.svc.ramTotalGb.toFixed(1) + " GiB"
                    : "--"
                fraction: card.svc ? card.svc.ramPercent / 100 : 0
                barColor: Root.Theme.base0D
            }
            Metric {
                width: parent.width
                label: "Disk /"
                value: card.svc && card.svc.diskUsedGb >= 0
                    ? card.svc.diskUsedGb.toFixed(0) + " / " + card.svc.diskTotalGb.toFixed(0) + " GiB"
                    : "--"
                fraction: card.svc ? card.svc.diskPercent / 100 : 0
                barColor: Root.Theme.base0F
            }
        }
    }
}
