import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.SystemTray
import "../.." as Root

Item {
    id: root
    implicitWidth: trayRepeater.count > 0 ? trayRow.implicitWidth : 0
    implicitHeight: Root.Theme.barHeight
    visible: trayRepeater.count > 0

    property var barPanel: null

    Row {
        id: trayRow
        spacing: 4
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            Rectangle {
                id: trayItem
                required property var modelData
                width: 24
                height: 24
                radius: Root.Theme.radiusSmall
                color: itemMouse.containsMouse
                    ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.12)
                    : "transparent"
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                Behavior on color { ColorAnimation { duration: 120 } }

                Image {
                    id: trayIcon
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: trayItem.modelData.icon ?? ""
                    sourceSize: Qt.size(16, 16)
                    smooth: true
                    visible: status === Image.Ready

                    layer.enabled: itemMouse.containsMouse
                    layer.effect: DropShadow {
                        transparentBorder: true
                        color: Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.4)
                        radius: 6
                        samples: 13
                    }
                }

                // Fallback when icon image unavailable
                Text {
                    anchors.centerIn: parent
                    text: trayItem.modelData.title ? trayItem.modelData.title.charAt(0).toUpperCase() : "?"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 10; bold: true }
                    visible: trayIcon.status !== Image.Ready
                }

                // Attention pulse dot
                Rectangle {
                    width: 6; height: 6; radius: 3
                    anchors { top: parent.top; right: parent.right; topMargin: -1; rightMargin: -1 }
                    color: Root.Theme.accentWarning
                    visible: trayItem.modelData.status === Status.NeedsAttention

                    SequentialAnimation on opacity {
                        running: visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: function(mouse) {
                        // Map tray item position to panel-window coordinates
                        let mapped = trayItem.mapToItem(null, 0, 0);
                        if (mouse.button === Qt.LeftButton) {
                            if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
                                trayItem.modelData.display(root.barPanel, mapped.x, Root.Theme.barHeight);
                            } else {
                                trayItem.modelData.activate();
                            }
                        } else if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                            trayItem.modelData.display(root.barPanel, mapped.x, Root.Theme.barHeight);
                        } else if (mouse.button === Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate();
                        }
                    }

                    onWheel: function(wheel) {
                        trayItem.modelData.scroll(wheel.angleDelta.y, false);
                    }
                }

                // Hover tooltip
                Rectangle {
                    id: tooltipBg
                    visible: itemMouse.containsMouse && tooltipLabel.text.length > 0
                    x: (parent.width - width) / 2
                    y: parent.height + 6
                    width: tooltipLabel.implicitWidth + 12
                    height: tooltipLabel.implicitHeight + 8
                    radius: Root.Theme.radiusSmall
                    color: Root.Theme.barBackground
                    border.width: Root.Theme.borderWidth
                    border.color: Root.Theme.borderColor
                    z: 100

                    layer.enabled: visible
                    layer.effect: DropShadow {
                        transparentBorder: true
                        color: Qt.rgba(0, 0, 0, 0.35)
                        radius: 8
                        samples: 17
                    }

                    Text {
                        id: tooltipLabel
                        anchors.centerIn: parent
                        text: trayItem.modelData.tooltipTitle || trayItem.modelData.title || ""
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: 11 }
                    }
                }
            }
        }
    }
}
