import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Item {
    id: root

    property int fixedTextWidth: 200
    property var playerService: Core.ServiceManager.player
    signal cavaToggled()

    property bool isPlaying: playerService ? playerService.isPlaying : false
    property string mediaText: playerService ? playerService.displayText : ""
    property bool hasMedia: mediaText.length > 0

    // Left: icon glyph bearing provides ~3px visual padding
    // Right: add 3px to match so text doesn't sit flush against group edge
    implicitWidth: hasMedia ? playIcon.width + 6 + Math.min(scrollText.contentWidth, fixedTextWidth) + 3 : 0
    implicitHeight: Root.Theme.barHeight
    opacity: hasMedia ? 1 : 0
    clip: true

    Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: Root.Theme.anim.resizeDuration; easing.type: Easing.InOutCubic } }

    // Hover background
    Rectangle {
        id: hoverBg
        anchors {
            fill: parent
            topMargin: 4
            bottomMargin: 4
        }
        radius: Root.Theme.radiusSmall
        color: mediaHover.containsMouse
            ? Root.Theme.layer1Hover
            : "transparent"
        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    }

    MouseArea {
        id: mediaHover
        anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.NoButton
    }

    Text {
        id: playIcon
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: root.isPlaying ? Root.Icons.mediaPlay : Root.Icons.mediaPause
        color: Root.Theme.domainMedia
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }

        // Bounce animation on play/pause toggle
        scale: 1.0
        SequentialAnimation {
            id: playBounce
            running: false
            NumberAnimation { target: playIcon; property: "scale"; to: 0.85; duration: 60; easing.type: Easing.InQuad }
            NumberAnimation { target: playIcon; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
                playBounce.restart();
                if (root.playerService) root.playerService.togglePlaying();
            }
        }
    }

    Components.ScrollingText {
        id: scrollText
        anchors { left: playIcon.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
        fixedWidth: root.fixedTextWidth
        text: root.mediaText
        textColor: mediaHover.containsMouse ? Root.Theme.domainMedia : Root.Theme.textPrimary
        textFont: Qt.font({ family: Root.Theme.fontFamily, pixelSize: Root.Theme.fontSize, bold: true })
        scrollEnabled: root.isPlaying

        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cavaToggled() }
    }
}
