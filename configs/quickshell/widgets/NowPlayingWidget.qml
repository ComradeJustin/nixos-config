import QtQuick
import ".." as Root
import "../components" as Components

// Background now playing widget with media info and controls
Components.WidgetFrame {
    id: root
    widgetName: "nowPlaying"

    property var playerService: null
    property bool showArt: true
    property int artSize: 80
    property int fontSize: 14

    property bool hasMedia: playerService ? playerService.hasMedia : false
    property bool isPlaying: playerService ? playerService.isPlaying : false
    property string trackTitle: playerService ? playerService.trackTitle : ""
    property string trackArtist: playerService ? playerService.trackArtist : ""
    property string trackArtUrl: playerService ? playerService.trackArtUrl : ""

    Row {
        spacing: 12

        Rectangle {
            visible: root.showArt
            width: root.artSize; height: root.artSize
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
                font { family: Root.Theme.fontIcons; pixelSize: root.artSize * 0.4 }
                visible: !root.trackArtUrl || artImage.status !== Image.Ready
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                text: root.trackTitle || "Unknown"
                color: Root.Theme.widgetText
                font { family: Root.Theme.fontFamily; pixelSize: root.fontSize; bold: true }
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
            }

            Text {
                text: root.trackArtist || "Unknown Artist"
                color: Root.Theme.widgetTextDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Math.round(root.fontSize * 0.85) }
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
            }

            Row {
                spacing: 16

                Components.IconButton {
                    icon: Root.Theme.iconSkipBack
                    iconColor: Root.Theme.textAccent
                    size: Math.round(root.fontSize * 1.5)
                    onClicked: if (root.playerService) root.playerService.previous()
                }

                Components.IconButton {
                    icon: root.isPlaying ? Root.Theme.iconPause : Root.Theme.iconPlay
                    iconColor: Root.Theme.textAccent
                    size: Math.round(root.fontSize * 1.7)
                    onClicked: if (root.playerService) root.playerService.togglePlaying()
                }

                Components.IconButton {
                    icon: Root.Theme.iconSkipFwd
                    iconColor: Root.Theme.textAccent
                    size: Math.round(root.fontSize * 1.5)
                    onClicked: if (root.playerService) root.playerService.next()
                }
            }
        }
    }
}
