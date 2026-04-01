import QtQuick
import "../.." as Root
import "../../components" as Components

Item {
    id: root

    property int fixedTextWidth: 200
    property var playerService: null
    signal cavaToggled()

    property bool isPlaying: playerService ? playerService.isPlaying : false
    property string mediaText: playerService ? playerService.displayText : ""

    visible: mediaText.length > 0

    implicitWidth: visible ? playIcon.width + 6 + fixedTextWidth : 0
    implicitHeight: Root.Theme.barHeight

    // Hover background
    Rectangle {
        id: hoverBg
        anchors.fill: parent; anchors.margins: -4
        radius: Root.Theme.radiusSmall
        color: mediaHover.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
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
        text: root.isPlaying ? Root.Theme.iconMediaPlay : Root.Theme.iconMediaPause
        color: Root.Theme.domainMedia
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { if (root.playerService) root.playerService.togglePlaying(); }
        }
    }

    Components.ScrollingText {
        anchors { left: playIcon.right; leftMargin: 6 }
        fixedWidth: root.fixedTextWidth
        text: root.mediaText
        textColor: mediaHover.containsMouse ? Root.Theme.domainMedia : Root.Theme.textDimmed
        textFont: Qt.font({ family: Root.Theme.fontFamily, pixelSize: Root.Theme.fontSize, bold: true })
        scrollEnabled: root.isPlaying

        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cavaToggled() }
    }
}
