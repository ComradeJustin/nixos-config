import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Root.Theme { id: theme }

    signal clicked()

    Text {
        id: icon
        text: theme.iconPower
        color: theme.textAccent
        font { family: theme.fontFamily; pixelSize: theme.iconSize + 2 }
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
