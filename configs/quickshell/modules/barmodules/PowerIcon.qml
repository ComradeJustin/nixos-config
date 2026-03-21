import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    signal clicked()

    Text {
        id: icon
        text: Root.Theme.iconPower
        color: Root.Theme.accentDanger
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize + 2 }
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
