import QtQuick
import "../.." as Root

Item {
    id: root

    property var powerMenuRef: null

    implicitWidth: powerText.implicitWidth
    implicitHeight: Root.Theme.barHeight

    Text {
        id: powerText
        text: Root.Theme.iconPower
        color: Root.Theme.accentDanger
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize + 2 }
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { if (root.powerMenuRef) root.powerMenuRef.toggle(); }
    }
}
