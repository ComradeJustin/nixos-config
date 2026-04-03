import QtQuick
import "../.." as Root

Item {
    id: root

    property var notifRef: null

    implicitWidth: gearText.implicitWidth
    implicitHeight: Root.Theme.barHeight

    Text {
        id: gearText
        text: Root.Theme.iconGear
        color: (root.notifRef && root.notifRef.showing) ? Root.Theme.domainSettings : Root.Theme.textDimmed
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { if (root.notifRef) root.notifRef.toggle(); }
    }
}
