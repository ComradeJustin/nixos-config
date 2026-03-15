import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Root.Theme { id: theme }

    property bool isOpen: false
    signal clicked()

    Text {
        id: icon
        text: theme.iconGear
        color: root.isOpen ? theme.textAccent : theme.textPrimary
        font { family: theme.fontFamily; pixelSize: theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
