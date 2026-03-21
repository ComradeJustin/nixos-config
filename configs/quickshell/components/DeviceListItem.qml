import QtQuick
import ".." as Root

// Reusable list item for devices (WiFi networks, Bluetooth devices, Audio outputs/inputs)
Rectangle {
    id: item

    property string icon: ""
    property string label: ""
    property bool isActive: false
    property bool showActiveBackground: false  // For audio device selection
    property color accentColor: Root.Theme.textAccent  // Accent color for active state

    signal clicked()

    width: parent ? parent.width : 200
    height: 36
    radius: Root.Theme.radiusSmall
    color: {
        if (showActiveBackground && isActive)
            return Qt.rgba(item.accentColor.r, item.accentColor.g, item.accentColor.b, 0.1);
        if (mouse.containsMouse)
            return Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06);
        return "transparent";
    }

    Row {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 12
            right: parent.right
            rightMargin: 12
        }
        spacing: 10

        Text {
            text: item.icon
            color: item.isActive ? item.accentColor : Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: 16 }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: item.label
            color: item.isActive ? item.accentColor : Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: 13; bold: item.isActive }
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: parent.width - 30
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }
}
