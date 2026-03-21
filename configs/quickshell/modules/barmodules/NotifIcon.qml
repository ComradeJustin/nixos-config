import QtQuick
import QtQuick.Layouts
import "../.." as Root

// Notification bell icon with unread count badge.
// Set `notifRef` to the Notifications module for state access.
Item {
    id: root
    implicitWidth: iconContainer.implicitWidth
    implicitHeight: Root.Theme.barHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    property var notifRef: null
    property int unread: notifRef ? notifRef.unreadCount : 0
    property bool historyOpen: notifRef ? notifRef.showHistory : false
    property bool isDnd: notifRef ? notifRef.dnd : false

    Item {
        id: iconContainer
        implicitWidth: bellIcon.implicitWidth + (badge.visible ? 6 : 0)
        implicitHeight: Root.Theme.barHeight
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: bellIcon
            text: root.isDnd ? Root.Theme.iconDnd
                : root.unread > 0 ? Root.Theme.iconBellBadge
                : Root.Theme.iconBell
            color: root.isDnd ? Root.Theme.accentWarning
                 : root.historyOpen ? Root.Theme.domainNotifications
                 : root.unread > 0 ? Root.Theme.domainNotifications
                 : Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── Unread count badge (hidden during DND) ──
        Rectangle {
            id: badge
            visible: root.unread > 0 && !root.isDnd
            width: Math.max(14, badgeText.implicitWidth + 6)
            height: 14
            radius: 7
            color: Root.Theme.domainNotifications
            anchors {
                left: bellIcon.right
                leftMargin: -6
                top: bellIcon.top
                topMargin: 2
            }

            Text {
                id: badgeText
                text: root.unread > 99 ? "99+" : root.unread
                color: Root.Theme.base00
                font { family: Root.Theme.fontFamily; pixelSize: 9; bold: true }
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
