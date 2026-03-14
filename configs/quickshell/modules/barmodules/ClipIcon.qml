import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: theme.barHeight

    Root.Theme { id: theme }

    property var clipRef: null
    property bool isOpen: clipRef ? clipRef.showClipboard : false

    Text {
        id: icon
        text: theme.iconClipboard
        color: root.isOpen ? theme.textAccent : theme.textPrimary
        font { family: theme.fontFamily; pixelSize: theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.clipRef) root.clipRef.toggle();
        }
    }
}
