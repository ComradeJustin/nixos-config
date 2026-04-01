import QtQuick
import ".." as Root

// Reusable hover-state icon button (Rectangle + Text + MouseArea).
// Usage:
//   IconButton { icon: Theme.iconPower; onClicked: powerMenu.toggle() }
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Root.Theme.textDimmed
    property color hoverColor: Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08)
    property int size: 28

    signal clicked()

    width: size
    height: size
    radius: Root.Theme.radiusSmall
    color: mouse.containsMouse ? hoverColor : "transparent"

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: mouse.containsMouse ? root.iconColor : Root.Theme.textDimmed
        font { family: Root.Theme.fontFamily; pixelSize: 16 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
