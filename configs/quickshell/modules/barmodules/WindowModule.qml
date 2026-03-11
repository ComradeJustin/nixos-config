import QtQuick
import QtQuick.Layouts
import Niri 0.1
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property int maxLength: 50

    Niri {
        id: niri
        Component.onCompleted: connect()

        onErrorOccurred: function(error) {
            console.warn("WindowModule: niri error:", error);
        }
    }

    property string windowTitle: niri.focusedWindow?.title ?? ""
    property string windowIcon:  niri.focusedWindow?.iconPath ?? ""

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        visible: root.windowTitle.length > 0

        Image {
            source: root.windowIcon.length > 0 ? "file://" + root.windowIcon : ""
            sourceSize.width: theme.iconSize
            sourceSize.height: theme.iconSize
            width: theme.iconSize
            height: theme.iconSize
            visible: root.windowIcon.length > 0
            smooth: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                let title = root.windowTitle;
                if (root.maxLength > 0 && title.length > root.maxLength)
                    title = title.substring(0, root.maxLength) + "…";
                return title;
            }
            color: theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
