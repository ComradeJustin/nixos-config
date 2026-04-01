import QtQuick
import Niri 0.1
import "../.." as Root
import "../../components" as Components

Item {
    id: root

    property int fixedTextWidth: 180

    Niri {
        id: niri
        Component.onCompleted: connect()
        onErrorOccurred: function(error) { console.warn("WindowModule: niri error:", error); }
    }

    property string windowTitle: niri.focusedWindow?.title ?? ""
    property string windowIcon:  niri.focusedWindow?.iconPath ?? ""

    visible: windowTitle.length > 0
    property bool hasIcon: windowIcon.length > 0

    implicitWidth: visible ? (hasIcon ? Root.Theme.iconSize + 6 : 0) + fixedTextWidth : 0
    implicitHeight: Root.Theme.barHeight

    Image {
        id: winIcon
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        source: root.hasIcon ? "file://" + root.windowIcon : ""
        sourceSize.width: Root.Theme.iconSize
        sourceSize.height: Root.Theme.iconSize
        width: Root.Theme.iconSize; height: Root.Theme.iconSize
        visible: root.hasIcon; smooth: true
    }

    Components.ScrollingText {
        anchors {
            left: root.hasIcon ? winIcon.right : parent.left
            leftMargin: root.hasIcon ? 6 : 0
        }
        fixedWidth: root.fixedTextWidth
        text: root.windowTitle
        textColor: Root.Theme.textDimmed
    }
}
