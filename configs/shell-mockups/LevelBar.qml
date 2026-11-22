import QtQuick

// A level: the filled part is solid, the rest is a halftone.
// Used for signal, volume and battery.
Item {
    id: root

    // How full the bar is, from 0 to 1.
    property real level: 0
    property color fillColor: Theme.ink
    property color emptyColor: Theme.rule

    implicitWidth: 32
    implicitHeight: 6

    Dither {
        anchors.fill: parent
        color: root.emptyColor
    }

    Rectangle {
        width: Math.round(root.width * Math.max(0, Math.min(1, root.level)))
        height: parent.height
        color: root.fillColor
    }
}
