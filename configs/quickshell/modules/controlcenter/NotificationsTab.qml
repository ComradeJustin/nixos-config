import QtQuick
import QtQuick.Layouts
import "../.." as Root
import "../../components" as Components

// Notifications tab content for ControlCenter
Flickable {
    id: root

    property var notifService: null

    contentHeight: notifCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: notifCol
        width: parent.width
        spacing: 4

        Components.EmptyState {
            visible: root.notifService ? root.notifService.stacks.count === 0 : true
            message: "No notifications"
            preferredHeight: 60
        }

        Repeater {
            model: root.notifService ? root.notifService.stacks : null

            Rectangle {
                id: notifItem
                width: notifCol.width
                // Header items get full padding, sub-items are smaller
                height: model.isHeader ? (nRow.implicitHeight + 14) : (nRow.implicitHeight + 10)
                radius: Root.Theme.radiusSmall
                // Background color for better distinction
                color: {
                    if (nHover.containsMouse)
                        return Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08);
                    return model.isHeader ? Root.Theme.notifItemBg : Root.Theme.notifSubItemBg;
                }
                clip: true
                x: 0
                Behavior on x { NumberAnimation { duration: 150 } }

                RowLayout {
                    id: nRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                    spacing: 10

                    // Notification icon - smaller for sub-items
                    Item {
                        Layout.preferredWidth: model.isHeader ? 30 : 24
                        Layout.preferredHeight: model.isHeader ? 30 : 24
                        Layout.alignment: Qt.AlignTop

                        Image {
                            id: nNotifImg
                            anchors.fill: parent
                            source: model.imagePath || ""
                            sourceSize.width: model.isHeader ? 30 : 24
                            sourceSize.height: model.isHeader ? 30 : 24
                            visible: status === Image.Ready
                            smooth: true
                            fillMode: Image.PreserveAspectCrop
                            cache: false  // Disable caching to ensure updated images are shown
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Root.Theme.radiusSmall
                            color: Root.Theme.ccIconBg  // Muted icon placeholder
                            visible: nNotifImg.status !== Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: (model.appName || "?").charAt(0).toUpperCase()
                                color: Root.Theme.textSubtle
                                font { family: Root.Theme.fontFamily; pixelSize: model.isHeader ? 13 : 11; bold: true }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: model.appName
                                color: Root.Theme.notifAppName
                                font { family: Root.Theme.fontFamily; pixelSize: 11 }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: model.timestamp
                                color: Root.Theme.textSubtle
                                font { family: Root.Theme.fontFamily; pixelSize: 10 }
                            }

                            Rectangle {
                                visible: model.isHeader && model.count > 1
                                width: Math.max(18, bdgTxt.implicitWidth + 8)
                                height: 18
                                radius: Root.Theme.radiusSmall
                                color: Root.Theme.domainNotifications

                                Text {
                                    id: bdgTxt
                                    anchors.centerIn: parent
                                    text: model.count
                                    color: Root.Theme.barBackground
                                    font { family: Root.Theme.fontFamily; pixelSize: 10; bold: true }
                                }
                            }

                            Text {
                                visible: model.isHeader && model.count > 1
                                text: model.expanded ? "▾" : "▸"
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 12 }
                            }
                        }

                        Text {
                            text: model.summary
                            color: Root.Theme.notifTitle
                            // Smaller font for sub-items
                            font { family: Root.Theme.fontFamily; pixelSize: model.isHeader ? 13 : 12; bold: true }
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.body
                            color: Root.Theme.notifBody
                            // Smaller font for sub-items
                            font { family: Root.Theme.fontFamily; pixelSize: model.isHeader ? 12 : 11 }
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: model.isHeader ? 2 : 1
                            elide: Text.ElideRight
                            visible: model.body !== ""
                            textFormat: Text.PlainText
                        }
                    }
                }

                Rectangle {
                    visible: !model.isHeader
                    anchors { left: parent.left; leftMargin: 50; right: parent.right; rightMargin: 10; bottom: parent.bottom }
                    height: 1
                    color: Root.Theme.textDimmed
                    opacity: 0.06
                }

                MouseArea {
                    id: nHover
                    anchors.fill: parent
                    hoverEnabled: true
                    property real startX: 0

                    onPressed: function(mouse) { startX = mouse.x; }
                    onPositionChanged: function(mouse) { if (pressed) notifItem.x = mouse.x - startX; }
                    onReleased: function(mouse) {
                        if (Math.abs(notifItem.x) > notifItem.width * 0.35) {
                            if (model.isHeader && model.count > 1)
                                root.notifService.removeApp(model.appName);
                            else
                                root.notifService.removeOne(model.nId);
                        } else {
                            notifItem.x = 0;
                            if (model.isHeader && model.count > 1)
                                root.notifService.toggleExpand(model.appName);
                        }
                    }
                }
            }
        }
    }
}
