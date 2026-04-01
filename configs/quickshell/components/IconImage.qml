import QtQuick
import Quickshell
import ".." as Root

// Image with auto icon resolution + placeholder fallback
Item {
    id: root

    property string source: ""
    property string fallbackText: "?"
    property color fallbackColor: Root.Theme.ccIconBg
    property int size: Root.Theme.iconSize

    width: size
    height: size

    Image {
        id: img
        anchors.fill: parent
        source: {
            if (!root.source || root.source === "") return "";
            if (root.source.indexOf("/") !== -1) return "file://" + root.source;
            return Quickshell.iconPath(root.source, true);
        }
        sourceSize.width: root.size
        sourceSize.height: root.size
        visible: status === Image.Ready
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        visible: img.status !== Image.Ready
        color: root.fallbackColor
        radius: Root.Theme.radiusSmall

        Text {
            anchors.centerIn: parent
            text: root.fallbackText
            color: Root.Theme.textSubtle
            font { family: Root.Theme.fontFamily; pixelSize: root.size * 0.55; bold: true }
        }
    }
}
