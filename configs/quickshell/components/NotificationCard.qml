import QtQuick
import QtQuick.Layouts
import ".." as Root

// Shared notification rendering for toast popups and notification history.
// Set compact: true for CC tab items (smaller icons, tighter spacing).
// Set animate: true for toast slide-in from right.
// Set swipeDismiss: true to enable swipe-to-dismiss gesture.
Item {
    id: root

    property string appName: ""
    property string summary: ""
    property string body: ""
    property string imagePath: ""
    property string timestamp: ""
    property int count: 1
    property bool compact: false
    property bool expanded: false
    property bool isHeader: true
    property bool animate: false
    property bool swipeDismiss: false

    signal dismissed()
    signal swiping(real progress)  // 0-1 progress of swipe

    readonly property int iconSize: compact ? (isHeader ? 30 : 24) : Root.Theme.notifIconSize

    implicitWidth: parent ? parent.width : 300
    implicitHeight: row.implicitHeight + (compact ? (isHeader ? 14 : 10) : Root.Theme.notifPadding * 2)

    // Slide-in entrance animation
    opacity: animate ? 0 : 1
    transform: Translate { id: slideTransform; x: root.animate ? 60 : 0 }

    Component.onCompleted: {
        if (animate) {
            entranceAnim.start();
        }
    }

    ParallelAnimation {
        id: entranceAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Root.Theme.animNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: slideTransform; property: "x"; from: 60; to: 0; duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    // ── Swipe-to-dismiss mechanics ──
    property real _swipeX: 0
    property bool _swiping: false

    Item {
        id: swipeContainer
        anchors.fill: parent
        x: root._swipeX

        opacity: {
            if (!root.swipeDismiss) return 1;
            let progress = Math.abs(root._swipeX) / root.width;
            return Math.max(0, 1 - progress * 1.2);
        }

        // Snap back or dismiss
        Behavior on x {
            enabled: !root._swiping
            NumberAnimation { duration: Root.Theme.anim.bounceDuration; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
        }

        RowLayout {
            id: row
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                margins: compact ? 10 : Root.Theme.notifPadding
            }
            spacing: 10

            // Notification icon with fallback
            Item {
                Layout.preferredWidth: root.iconSize
                Layout.preferredHeight: root.iconSize
                Layout.alignment: Qt.AlignTop

                Image {
                    id: img
                    anchors.fill: parent
                    source: root.imagePath || ""
                    sourceSize.width: root.iconSize
                    sourceSize.height: root.iconSize
                    visible: status === Image.Ready
                    smooth: true
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Root.Theme.radiusSmall
                    color: Root.Theme.ccIconBg
                    visible: img.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: (root.appName || "?").charAt(0).toUpperCase()
                        color: Root.Theme.textSubtle
                        font {
                            family: Root.Theme.fontFamily
                            pixelSize: compact ? (root.isHeader ? 13 : 11) : 14
                            bold: true
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: compact ? 1 : 2

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.appName
                        color: Root.Theme.notifAppName
                        font { family: Root.Theme.fontFamily; pixelSize: compact ? 11 : 12 }
                        visible: root.appName !== ""
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.timestamp
                        color: Root.Theme.textSubtle
                        font { family: Root.Theme.fontFamily; pixelSize: 10 }
                        visible: compact && root.timestamp !== ""
                    }

                    Rectangle {
                        visible: root.isHeader && root.count > 1
                        width: Math.max(compact ? 18 : 16, badgeText.implicitWidth + (compact ? 8 : 6))
                        height: compact ? 18 : 16
                        radius: Root.Theme.radiusSmall
                        color: Root.Theme.domainNotifications

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: root.count
                            color: Root.Theme.barBackground
                            font { family: Root.Theme.fontFamily; pixelSize: compact ? 10 : 9; bold: true }
                        }
                    }

                    Text {
                        visible: compact && root.isHeader && root.count > 1
                        text: root.expanded ? "▾" : "▸"
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: 12 }
                    }
                }

                Text {
                    text: root.summary
                    color: Root.Theme.notifTitle
                    font {
                        family: Root.Theme.fontFamily
                        pixelSize: compact ? (root.isHeader ? 13 : 12) : 13
                        bold: true
                    }
                    Layout.fillWidth: true
                    wrapMode: compact ? Text.NoWrap : Text.Wrap
                    maximumLineCount: compact ? 1 : 2
                    elide: Text.ElideRight
                }

                Text {
                    text: root.body
                    color: Root.Theme.notifBody
                    font {
                        family: Root.Theme.fontFamily
                        pixelSize: compact ? (root.isHeader ? 12 : 11) : 12
                    }
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    maximumLineCount: compact ? (root.isHeader ? 2 : 1) : 3
                    elide: Text.ElideRight
                    visible: root.body !== ""
                    textFormat: Text.PlainText
                }
            }
        }
    }

    // Swipe drag handler
    MouseArea {
        id: swipeArea
        anchors.fill: parent
        enabled: root.swipeDismiss
        visible: root.swipeDismiss

        property real _startX: 0
        property bool _dragging: false

        onPressed: function(mouse) {
            _startX = mouse.x;
            _dragging = false;
        }

        onPositionChanged: function(mouse) {
            let dx = mouse.x - _startX;
            // Only start dragging after a threshold to avoid interfering with clicks
            if (!_dragging && Math.abs(dx) > 8) {
                _dragging = true;
                root._swiping = true;
            }
            if (_dragging) {
                // Only allow right-swipe (positive direction) for dismiss
                root._swipeX = Math.max(0, dx);
                root.swiping(Math.min(1, root._swipeX / root.width));
            }
        }

        onReleased: {
            root._swiping = false;
            if (_dragging) {
                let threshold = root.width * 0.35;
                if (root._swipeX > threshold) {
                    // Dismiss: animate off screen
                    dismissSwipeAnim.start();
                } else {
                    // Snap back
                    root._swipeX = 0;
                }
                _dragging = false;
            }
        }

        onCanceled: {
            root._swiping = false;
            root._swipeX = 0;
            _dragging = false;
        }
    }

    NumberAnimation {
        id: dismissSwipeAnim
        target: root
        property: "_swipeX"
        to: root.width * 1.2
        duration: Root.Theme.anim.exitDuration
        easing.type: Easing.InCubic
        onFinished: root.dismissed()
    }
}
