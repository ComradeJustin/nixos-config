import QtQuick
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// SystemMonitorCard — CPU, RAM, and disk at a glance with sparklines.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: 120

    readonly property var svc: Core.ServiceManager.systemStats

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // Soft domain glow
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(Root.Theme.domainSystem.r,
                               Root.Theme.domainSystem.g,
                               Root.Theme.domainSystem.b, 0.12)
            }
            GradientStop { position: 0.9; color: "transparent" }
        }
    }

    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Root.Theme.spacingM
        }
        spacing: Root.Theme.spacingM

        // Icon tile
        Rectangle {
            id: iconTile
            width: 60; height: 60
            radius: Root.Theme.radiusSmall
            color: Qt.rgba(Root.Theme.domainSystem.r,
                           Root.Theme.domainSystem.g,
                           Root.Theme.domainSystem.b, 0.22)
            border.width: 1
            border.color: Qt.rgba(Root.Theme.domainSystem.r,
                                  Root.Theme.domainSystem.g,
                                  Root.Theme.domainSystem.b, 0.5)

            Text {
                anchors.centerIn: parent
                text: Root.Icons.monitor
                color: Root.Theme.domainSystem
                font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize5XL }
            }
        }

        // Stats column
        Column {
            width: parent.width - iconTile.width - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // CPU row
            Row {
                width: parent.width
                spacing: Root.Theme.spacingS

                Column {
                    width: parent.width - cpuGraph.width - 8
                    spacing: 1

                    Text {
                        text: "CPU"
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    }
                    Text {
                        text: card.svc ? card.svc.cpuPercent + "%" : "--"
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL; bold: true }
                    }
                }

                Components.Graph {
                    id: cpuGraph
                    width: 80; height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    values: card.svc ? card.svc.cpuHistory : []
                    lineColor: Root.Theme.domainSystem
                }
            }

            // RAM row
            Row {
                width: parent.width
                spacing: Root.Theme.spacingS

                Column {
                    width: parent.width - ramGraph.width - 8
                    spacing: 1

                    Text {
                        text: "RAM"
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    }
                    Text {
                        text: card.svc ? card.svc.ramUsedGb.toFixed(1) + " / " + card.svc.ramTotalGb.toFixed(1) + " GB" : "--"
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL; bold: true }
                    }
                }

                Components.Graph {
                    id: ramGraph
                    width: 80; height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    values: card.svc ? card.svc.ramHistory : []
                    lineColor: Root.Theme.base0D
                }
            }

            // Disk + uptime footer
            Row {
                width: parent.width
                spacing: Root.Theme.spacingM

                Text {
                    text: card.svc && card.svc.diskPercent >= 0
                        ? "Disk " + card.svc.diskPercent + "%"
                        : ""
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    visible: text.length > 0
                }

                Text {
                    text: card.svc && card.svc.uptime.length > 0
                        ? "Up " + card.svc.uptime
                        : ""
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    visible: text.length > 0
                }
            }
        }
    }
}
