import QtQuick
import "../.." as Root
import "../../core" as Core

Item {
    id: root

    implicitWidth: powerText.implicitWidth
    implicitHeight: Root.Theme.barHeight

    Text {
        id: powerText
        text: Root.Icons.power
        color: Root.Theme.accentDanger
        font { family: Root.Theme.fontMono; pixelSize: Root.Theme.iconSize + 2 }
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { let pm = Core.ServiceManager.powerMenu; if (pm) pm.toggle(); }
    }
}
