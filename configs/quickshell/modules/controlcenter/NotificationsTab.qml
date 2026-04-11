import QtQuick
import QtQuick.Layouts
import "../.." as Root
import "../../components" as Components

// Notifications tab content for ControlCenter
// Supports:
//   • Directional swipe: right = dismiss latest, left = dismiss group
//   • Keyboard nav: j/k to move, d to dismiss, Enter to expand
//   • Notification action buttons
Components.SmoothFlickable {
    id: root

    property var notifService: null

    // ── Keyboard selection ──
    property int selectedIndex: -1
    property int stackCount: notifService ? notifService.stacks.count : 0

    function moveDown() {
        if (stackCount === 0) return;
        selectedIndex = Math.min(selectedIndex + 1, stackCount - 1);
    }
    function moveUp() {
        if (stackCount === 0) return;
        selectedIndex = Math.max(selectedIndex - 1, 0);
    }
    function dismissSelected() {
        if (selectedIndex < 0 || selectedIndex >= stackCount) return;
        let item = notifService.stacks.get(selectedIndex);
        if (!item) return;
        if (item.isHeader && item.count > 1)
            notifService.removeApp(item.appName);
        else
            notifService.removeOne(item.nId);
        // Clamp selection after removal
        if (selectedIndex >= notifService.stacks.count)
            selectedIndex = Math.max(0, notifService.stacks.count - 1);
    }
    function activateSelected() {
        if (selectedIndex < 0 || selectedIndex >= stackCount) return;
        let item = notifService.stacks.get(selectedIndex);
        if (!item) return;
        if (item.isHeader && item.count > 1)
            notifService.toggleExpand(item.appName);
    }

    contentHeight: notifCol.implicitHeight
    clip: true

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
                height: nCol.implicitHeight + (model.isHeader ? 14 : 10)
                radius: Root.Theme.radiusSmall
                color: {
                    // Keyboard selection highlight
                    if (model.index === root.selectedIndex)
                        return Qt.rgba(Root.Theme.domainNotifications.r, Root.Theme.domainNotifications.g, Root.Theme.domainNotifications.b, 0.12);
                    if (nHover.containsMouse)
                        return Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08);
                    return model.isHeader ? Root.Theme.notifItemBg : Root.Theme.notifSubItemBg;
                }
                clip: true
                x: 0
                Behavior on x { NumberAnimation { duration: 150 } }

                // Swipe direction hint — subtle background tint
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: notifItem.x !== 0 && model.isHeader && model.count > 1
                    color: notifItem.x > 0
                        ? Qt.rgba(Root.Theme.domainNotifications.r, Root.Theme.domainNotifications.g, Root.Theme.domainNotifications.b, 0.08)
                        : Qt.rgba(Root.Theme.accentDanger.r, Root.Theme.accentDanger.g, Root.Theme.accentDanger.b, 0.08)
                }

                // Urgency border — full outline around the card.
                border.width: model.urgency != 1 ? 2 : 0
                border.color: model.urgency == 2 ? Root.Theme.notifUrgentBorder
                            : model.urgency == 0 ? Root.Theme.notifLowBorder
                            : "transparent"

                ColumnLayout {
                    id: nCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                    spacing: 0

                    RowLayout {
                        id: nRow
                        Layout.fillWidth: true
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
                                cache: false
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Root.Theme.radiusSmall
                                color: Root.Theme.ccIconBg
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
                                font { family: Root.Theme.fontFamily; pixelSize: model.isHeader ? 13 : 12; bold: true }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: model.body
                                color: Root.Theme.notifBody
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

                    // ── Action buttons ──
                    Flow {
                        id: actionFlow
                        Layout.fillWidth: true
                        Layout.topMargin: visible ? 4 : 0
                        spacing: 4
                        visible: _actions.length > 0

                        property var _actions: {
                            try { return JSON.parse(model.actionsJson || "[]"); }
                            catch(e) { return []; }
                        }

                        Repeater {
                            model: actionFlow._actions

                            Rectangle {
                                width: actLabel.implicitWidth + 12
                                height: 20
                                radius: Root.Theme.radiusSmall
                                color: actMouse.containsMouse
                                    ? Qt.rgba(Root.Theme.domainNotifications.r, Root.Theme.domainNotifications.g, Root.Theme.domainNotifications.b, 0.2)
                                    : Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08)

                                Text {
                                    id: actLabel
                                    anchors.centerIn: parent
                                    text: modelData.text
                                    color: actMouse.containsMouse ? Root.Theme.domainNotifications : Root.Theme.textDimmed
                                    font { family: Root.Theme.fontFamily; pixelSize: 10 }
                                }

                                MouseArea {
                                    id: actMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.notifService)
                                            root.notifService.invokeAction(notifItem._nId, modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

                // Store nId for action invocation
                property int _nId: model.nId

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

                    onPressed: function(mouse) {
                        startX = mouse.x;
                        root.selectedIndex = model.index;
                    }
                    onPositionChanged: function(mouse) { if (pressed) notifItem.x = mouse.x - startX; }
                    onReleased: function(mouse) {
                        // Directional swipe for grouped headers:
                        //   Right swipe (x > 0) → dismiss latest only
                        //   Left swipe  (x < 0) → dismiss entire group
                        // Non-header items or single-count headers: any direction removes the one item
                        if (Math.abs(notifItem.x) > notifItem.width * 0.35) {
                            if (model.isHeader && model.count > 1) {
                                if (notifItem.x > 0)
                                    root.notifService.removeLatestFromApp(model.appName);
                                else
                                    root.notifService.removeApp(model.appName);
                            } else {
                                root.notifService.removeOne(model.nId);
                            }
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
