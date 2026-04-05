import QtQuick
import "../.." as Root
import "../../core" as Core

Item {
    id: root

    property var notifRef: null
    property var notifSvc: Core.ServiceManager.notif
    property int unread: notifSvc ? notifSvc.unreadCount : 0

    implicitWidth: gearText.implicitWidth
    implicitHeight: Root.Theme.barHeight

    Text {
        id: gearText
        text: root.unread > 0 ? Root.Icons.bellBadge : Root.Icons.gear
        color: {
            if (root.unread > 0) return Root.Theme.domainNotifications;
            if (root.notifRef && root.notifRef.showing) return Root.Theme.domainSettings;
            return Root.Theme.textDimmed;
        }
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    }

    // Unread count badge
    Rectangle {
        visible: root.unread > 0
        anchors {
            left: gearText.right; leftMargin: -4
            top: gearText.top; topMargin: -2
        }
        width: Math.max(badgeText.implicitWidth + 6, height)
        height: 14
        radius: 7
        color: Root.Theme.domainNotifications

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.unread > 99 ? "99+" : root.unread
            color: Root.Theme.base00
            font { family: Root.Theme.fontFamily; pixelSize: 9; bold: true }
        }

        // Bounce in on appearance
        scale: visible ? 1 : 0
        Behavior on scale {
            NumberAnimation { duration: Root.Theme.anim.bounceDuration; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.notifSvc) root.notifSvc.unreadCount = 0;
            if (root.notifRef) root.notifRef.toggle();
        }
    }
}
