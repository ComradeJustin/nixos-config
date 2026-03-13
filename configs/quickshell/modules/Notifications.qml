import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import ".." as Root

Scope {
    id: notifScope

    Root.Theme { id: theme }

    // ── Exposed state ──
    property bool showHistory: false
    property bool dnd: false
    property int unreadCount: 0

    function toggleHistory() {
        showHistory = !showHistory;
        if (showHistory) {
            historyPanel.visible = true;
            // Mark all as read
            unreadCount = 0;
        }
    }

    function clearHistory() {
        historyModel.clear();
        unreadCount = 0;
    }

    // ── Shared models ──
    ListModel { id: popupModel }
    ListModel { id: historyModel }

    // ── Notification server ──
    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        keepOnReload: false

        onNotification: function(notification) {
            notification.tracked = true;

            let timeout = theme.notifTimeout;
            if (notification.urgency === NotificationUrgency.Critical)
                timeout = timeout * 3;

            let entry = {
                "notifId":    notification.id,
                "appName":    notification.appName || "",
                "summary":    notification.summary || "",
                "body":       notification.body || "",
                "imagePath":  notification.image || notification.appIcon || "",
                "urgent":     notification.urgency === NotificationUrgency.Critical,
                "notifRef":   notification,
                "timeout":    timeout
            };

            if (!notifScope.dnd || entry.urgent) {
                if (popupModel.count >= theme.notifMaxVisible) {
                    let oldest = popupModel.get(0);
                    if (oldest && oldest.notifRef)
                        oldest.notifRef.expire();
                    popupModel.remove(0);
                }
                popupModel.append(entry);
            }

            historyModel.insert(0, {
                "appName":   entry.appName,
                "summary":   entry.summary,
                "body":      entry.body,
                "imagePath": entry.imagePath,
                "urgent":    entry.urgent
            });
            if (historyModel.count > 50)
                historyModel.remove(50, historyModel.count - 50);

            // Increment unread unless user is reading history
            if (!notifScope.showHistory)
                notifScope.unreadCount++;
        }
    }

    // ══════════════════════════════════
    // ── Popup panel (top-right toasts) ──
    // ══════════════════════════════════
    PanelWindow {
        id: popupPanel

        WlrLayershell.namespace: "quickshell-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors { top: true; right: true }
        margins.top: theme.notifMarginTop + theme.barHeight

        // Panel flush with screen edge so cards slide from true edge
        implicitWidth: theme.notifWidth + theme.notifMarginRight
        implicitHeight: popupColumn.implicitHeight
        color: "transparent"
        visible: popupModel.count > 0

        Column {
            id: popupColumn
            width: parent.width
            spacing: theme.notifSpacing

            Repeater {
                model: popupModel

                Item {
                    width: theme.notifWidth + theme.notifMarginRight
                    height: card.height
                    clip: true

                Rectangle {
                    id: card
                    width: theme.notifWidth
                    height: cardContent.implicitHeight + theme.notifPadding * 2
                    radius: theme.notifRadius
                    color: theme.notifBackground
                    border.color: model.urgent ? theme.notifUrgentBorder : "transparent"
                    border.width: model.urgent ? 2 : 0
                    opacity: 1

                    // Start off-screen right, slide to final position with margin
                    x: theme.notifWidth + theme.notifMarginRight
                    Component.onCompleted: {
                        x = 0;
                        dismissTimer.interval = model.timeout;
                        dismissTimer.start();
                    }

                    Behavior on x {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    Timer {
                        id: dismissTimer
                        onTriggered: card.dismiss()
                    }

                    function dismiss() {
                        card.opacity = 0;
                        removeTimer.start();
                    }

                    Timer {
                        id: removeTimer
                        interval: 160
                        onTriggered: {
                            if (model.notifRef)
                                model.notifRef.expire();
                            popupModel.remove(index);
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.dismiss()
                    }

                    RowLayout {
                        id: cardContent
                        anchors {
                            left: parent.left; right: parent.right; top: parent.top
                            margins: theme.notifPadding
                        }
                        spacing: 10

                        Image {
                            source: {
                                let p = model.imagePath;
                                if (!p || p === "") return "";
                                if (p.indexOf("://") !== -1) return p;
                                if (p.startsWith("/")) return "file://" + p;
                                return "image://icon/" + p;
                            }
                            sourceSize.width: theme.notifIconSize
                            sourceSize.height: theme.notifIconSize
                            Layout.preferredWidth: theme.notifIconSize
                            Layout.preferredHeight: theme.notifIconSize
                            Layout.alignment: Qt.AlignTop
                            visible: status === Image.Ready
                            smooth: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: model.appName
                                color: theme.notifAppName
                                font { family: theme.fontFamily; pixelSize: theme.notifBodySize }
                                visible: model.appName !== ""
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: model.summary
                                color: theme.notifTitle
                                font { family: theme.fontFamily; pixelSize: theme.notifTitleSize; bold: true }
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                text: model.body
                                color: theme.notifBody
                                font { family: theme.fontFamily; pixelSize: theme.notifBodySize }
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                visible: model.body !== ""
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }
                }
            }
        }
    }

    // ══════════════════════════════════
    // ── History panel ──
    // ══════════════════════════════════
    PanelWindow {
        id: historyPanel

        visible: false

        anchors { top: true; right: true }
        // Flush with bar — no gap, slide handles spacing
        margins.top: theme.barHeight
        margins.right: theme.notifMarginRight
        implicitWidth: theme.notifHistWidth
        // Fixed height so clip area is always big enough for slide
        implicitHeight: theme.notifHistMaxHeight

        WlrLayershell.namespace: "quickshell-notif-history"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: histRect
                width: parent.width
                height: historyInner.implicitHeight
                radius: theme.notifRadius
                color: theme.barBackground

                // Slide from behind bar to 6px below bar edge
                y: notifScope.showHistory ? 6 : -(height + 6)

                Behavior on y {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                // Hide panel after slide-out completes
                onYChanged: {
                    if (!notifScope.showHistory && y <= -(height + 5)) {
                        historyPanel.visible = false;
                    }
                }

                Column {
                    id: historyInner
                    width: parent.width
                    spacing: 0

                    // ── Header ──
                    RowLayout {
                        width: parent.width
                        height: 36

                        Text {
                            text: "Notifications"
                            color: theme.textPrimary
                            font { family: theme.fontFamily; pixelSize: theme.notifTitleSize; bold: true }
                            Layout.fillWidth: true
                            Layout.leftMargin: theme.notifPadding
                            verticalAlignment: Text.AlignVCenter
                        }

                        // ── DND toggle ──
                        Text {
                            text: notifScope.dnd ? theme.iconDnd : theme.iconDndOff
                            color: notifScope.dnd ? theme.textWarning : theme.textDimmed
                            font { family: theme.fontFamily; pixelSize: theme.iconSize }
                            Layout.rightMargin: 4
                            verticalAlignment: Text.AlignVCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notifScope.dnd = !notifScope.dnd
                            }
                        }

                        // ── Clear button ──
                        Text {
                            text: theme.iconTrash
                            color: historyModel.count > 0 ? theme.textDimmed : "transparent"
                            font { family: theme.fontFamily; pixelSize: theme.iconSize }
                            Layout.rightMargin: theme.notifPadding
                            verticalAlignment: Text.AlignVCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notifScope.clearHistory()
                            }
                        }
                    }

                    // ── Separator ──
                    Rectangle {
                        width: parent.width - theme.notifPadding * 2
                        height: 1
                        color: theme.textDimmed
                        opacity: 0.3
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // ── DND banner ──
                    Rectangle {
                        visible: notifScope.dnd
                        width: parent.width
                        height: 28
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            color: theme.textWarning
                            opacity: 0.15
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Do Not Disturb is on"
                            color: theme.textWarning
                            font { family: theme.fontFamily; pixelSize: 11 }
                        }
                    }

                    // ── Empty state ──
                    Text {
                        visible: historyModel.count === 0
                        text: "No notifications"
                        color: theme.textDimmed
                        font { family: theme.fontFamily; pixelSize: theme.notifBodySize }
                        width: parent.width
                        height: 60
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    // ── History items ──
                    Flickable {
                        visible: historyModel.count > 0
                        width: parent.width
                        height: Math.min(historyCol.implicitHeight, theme.notifHistMaxHeight - 80)
                        contentHeight: historyCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: historyCol
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: historyModel

                                Rectangle {
                                    width: historyCol.width
                                    height: histRow.implicitHeight + theme.notifPadding
                                    color: "transparent"

                                    RowLayout {
                                        id: histRow
                                        anchors {
                                            left: parent.left; right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            margins: theme.notifPadding
                                        }
                                        spacing: 10

                                        Image {
                                            source: {
                                                let p = model.imagePath;
                                                if (!p || p === "") return "";
                                                if (p.indexOf("://") !== -1) return p;
                                                if (p.startsWith("/")) return "file://" + p;
                                                return "image://icon/" + p;
                                            }
                                            sourceSize.width: 24
                                            sourceSize.height: 24
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignTop
                                            visible: status === Image.Ready
                                            smooth: true
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: model.appName
                                                color: theme.notifAppName
                                                font { family: theme.fontFamily; pixelSize: 10 }
                                                visible: model.appName !== ""
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: model.summary
                                                color: theme.notifTitle
                                                font { family: theme.fontFamily; pixelSize: theme.notifBodySize; bold: true }
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: model.body
                                                color: theme.notifBody
                                                font { family: theme.fontFamily; pixelSize: 11 }
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                visible: model.body !== ""
                                                textFormat: Text.PlainText
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width - theme.notifPadding * 2
                                        height: 1
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: theme.textDimmed
                                        opacity: 0.15
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
