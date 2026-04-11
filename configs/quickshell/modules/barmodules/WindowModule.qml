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
    property bool hasWindow: windowTitle.length > 0

    // Track window ID to detect actual focus changes
    property var _prevWindowId: null
    property var _currentWindowId: niri.focusedWindow?.id ?? null

    on_CurrentWindowIdChanged: {
        if (_prevWindowId !== null && _currentWindowId !== _prevWindowId) {
            if (_currentWindowId === null) {
                // Focused nothing — fade out
                fadeOutAnim.start();
            } else {
                // Switched window — crossfade
                crossfadeAnim.start();
            }
        } else if (_prevWindowId === null && _currentWindowId !== null) {
            // Went from no window to a window — fade in
            contentRow.opacity = 0;
            fadeInAnim.start();
        }
        _prevWindowId = _currentWindowId;
    }

    // Animate width so the group pill shrinks/grows smoothly
    implicitWidth: hasWindow ? (windowIcon.length > 0 ? Root.Theme.iconSize + 6 : 0) + fixedTextWidth : 0
    implicitHeight: Root.Theme.barHeight
    visible: implicitWidth > 0 || widthAnim.running

    Behavior on implicitWidth {
        id: widthAnim
        NumberAnimation { duration: 150; easing.type: Easing.InOutCubic }
    }

    // Crossfade: fade out, let bindings update, fade back in
    SequentialAnimation {
        id: crossfadeAnim
        NumberAnimation { target: contentRow; property: "opacity"; to: 0; duration: 80; easing.type: Easing.InCubic }
        NumberAnimation { target: contentRow; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }

    // Fade out when window unfocused
    NumberAnimation {
        id: fadeOutAnim
        target: contentRow; property: "opacity"
        to: 0; duration: 120; easing.type: Easing.InCubic
    }

    // Fade in when window first appears
    NumberAnimation {
        id: fadeInAnim
        target: contentRow; property: "opacity"
        to: 1; duration: 150; easing.type: Easing.OutCubic
    }

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Image {
            id: winIcon
            anchors.verticalCenter: parent.verticalCenter
            source: root.windowIcon.length > 0 ? "file://" + root.windowIcon : ""
            sourceSize.width: Root.Theme.iconSize
            sourceSize.height: Root.Theme.iconSize
            width: root.windowIcon.length > 0 ? Root.Theme.iconSize : 0
            height: Root.Theme.iconSize
            visible: root.windowIcon.length > 0
            smooth: true
        }

        Components.ScrollingText {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            fixedWidth: root.fixedTextWidth
            text: root.windowTitle
            textColor: Root.Theme.textDimmed
        }
    }

    // Gradient fade-out at the right edge
    Rectangle {
        x: contentRow.x + titleText.x + titleText.width - 24
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: Math.ceil(Root.Theme.fontSize * 1.5)
        visible: titleText.contentWidth > titleText.fixedWidth * 0.85
        opacity: contentRow.opacity

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Root.Config.bar.showGroups ? Root.Theme.layer1 : Root.Theme.barBackground }
        }
    }
}
