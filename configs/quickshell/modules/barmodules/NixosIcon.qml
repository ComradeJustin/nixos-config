import QtQuick
import "../.." as Root

// NixOS logo icon for the bar.
Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Root.Theme { id: theme }

    Text {
        id: icon
        text: theme.iconNixos
        color: theme.textAccent
        font { family: theme.fontFamily; pixelSize: theme.iconSize + 2 }
        anchors.verticalCenter: parent.verticalCenter
    }
}
