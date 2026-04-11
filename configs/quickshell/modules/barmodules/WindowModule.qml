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
        id: titleText
        anchors {
            left: root.hasIcon ? winIcon.right : parent.left
            leftMargin: root.hasIcon ? 6 : 0
        }
        fixedWidth: root.fixedTextWidth
        text: root.windowTitle
        textColor: Root.Theme.textDimmed
    }

    // Gradient fade-out at the right edge — overlays a smooth fade
    // from transparent → bar background instead of a hard clip edge.
    // Only visible when text is long enough to reach the edge.
    Rectangle {
        anchors {
            right: titleText.right
            verticalCenter: parent.verticalCenter
        }
        width: 24
        height: titleText.height
        visible: titleText.contentWidth > titleText.fixedWidth * 0.85

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Root.Theme.barBackground }
        }
    }
}
