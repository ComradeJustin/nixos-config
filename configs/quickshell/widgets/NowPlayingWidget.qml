import QtQuick
import ".." as Root

// Background now playing widget with media info and controls
Item {
    id: root

    // Required: PlayerService reference
    property var playerService: null

    // Config properties
    property bool showArt: true
    property int artSize: 80
    property int fontSize: 14

    // Computed properties
    property bool hasMedia: playerService ? playerService.hasMedia : false
    property bool isPlaying: playerService ? playerService.isPlaying : false
    property string trackTitle: playerService ? playerService.trackTitle : ""
    property string trackArtist: playerService ? playerService.trackArtist : ""
    property string trackArtUrl: playerService ? playerService.trackArtUrl : ""

    implicitWidth: content.implicitWidth + Root.Theme.widgetPadding * 2
    implicitHeight: content.implicitHeight + Root.Theme.widgetPadding * 2

    // Shadow layer
    Rectangle {
        anchors.fill: bg
        anchors.margins: -2
        anchors.topMargin: 2
        radius: Root.Theme.widgetRadius + 2
        color: Root.Theme.widgetShadowColor
        opacity: 0.4
    }

    // Widget background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Theme.widgetBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 12

        // Album art
        Rectangle {
            visible: root.showArt
            width: root.artSize
            height: root.artSize
            radius: Root.Theme.radiusSmall
            color: Root.Theme.base02
            clip: true

            Image {
                id: artImage
                anchors.fill: parent
                source: root.trackArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: Root.Theme.iconMusic
                color: Root.Theme.widgetTextDimmed
                font {
                    family: Root.Theme.fontIcons
                    pixelSize: root.artSize * 0.4
                }
                visible: !root.trackArtUrl || artImage.status !== Image.Ready
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Track title
            Text {
                text: root.trackTitle || "Unknown"
                color: Root.Theme.widgetText
                font {
                    family: Root.Theme.fontFamily
                    pixelSize: root.fontSize
                    bold: true
                }
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
            }

            // Artist
            Text {
                text: root.trackArtist || "Unknown Artist"
                color: Root.Theme.widgetTextDimmed
                font {
                    family: Root.Theme.fontFamily
                    pixelSize: Math.round(root.fontSize * 0.85)
                }
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
            }

            // Playback controls
            Row {
                spacing: 16

                Text {
                    text: Root.Theme.iconSkipBack
                    color: controlPrev.containsMouse ? Root.Theme.textAccent : Root.Theme.widgetTextDimmed
                    font {
                        family: Root.Theme.fontIcons
                        pixelSize: root.fontSize * 1.2
                    }
                    MouseArea {
                        id: controlPrev
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.playerService) root.playerService.previous()
                    }
                }

                Text {
                    text: root.isPlaying ? Root.Theme.iconPause : Root.Theme.iconPlay
                    color: controlPlay.containsMouse ? Root.Theme.textAccent : Root.Theme.widgetText
                    font {
                        family: Root.Theme.fontIcons
                        pixelSize: root.fontSize * 1.4
                    }
                    MouseArea {
                        id: controlPlay
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.playerService) root.playerService.togglePlaying()
                    }
                }

                Text {
                    text: Root.Theme.iconSkipFwd
                    color: controlNext.containsMouse ? Root.Theme.textAccent : Root.Theme.widgetTextDimmed
                    font {
                        family: Root.Theme.fontIcons
                        pixelSize: root.fontSize * 1.2
                    }
                    MouseArea {
                        id: controlNext
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.playerService) root.playerService.next()
                    }
                }
            }
        }
    }
}
