import QtQuick
import QtQuick.Layouts
import "../.." as Root

// Notification bell icon with unread count badge.
// Set `notifRef` to the Notifications module for state access.
Item {
    id: root
    implicitWidth: iconContainer.implicitWidth
    implicitHeight: theme.barHeight

    Root.Theme { id: theme }

    property var notifRef: null
    property int unread: notifRef ? notifRef.unreadCount : 0
    property bool historyOpen: notifRef ? notifRef.showHistory : false

    Item {
        id: iconContainer
        implicitWidth: bellIcon.implicitWidth + (badge.visible ? 6 : 0)
        implicitHeight: theme.barHeight
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: bellIcon
            text: root.unread > 0 ? theme.iconBellBadge : theme.iconBell
            color: root.historyOpen ? theme.textAccent
                 : root.unread > 0 ? theme.textWarning
                 : theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── Unread count badge ──
        Rectangle {
            id: badge
            visible: root.unread > 0
            width: Math.max(14, badgeText.implicitWidth + 6)
            height: 14
            radius: 7
            color: theme.textCritical
            anchors {
                left: bellIcon.right
                leftMargin: -6
                top: bellIcon.top
                topMargin: 2
            }

            Text {
                id: badgeText
                text: root.unread > 99 ? "99+" : root.unread
                color: theme.base00
                font { family: theme.fontFamily; pixelSize: 9; bold: true }
                anchors.centerIn: parent
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.notifRef) root.notifRef.toggleHistory();
            }
        }
    }
}
