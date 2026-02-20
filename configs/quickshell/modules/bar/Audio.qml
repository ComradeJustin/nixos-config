import QtQuick
import QtQuick.Layouts
import Quickshell


Rectangle {

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            audio.volume = AudioService.volume
            audio.muted = AudioService.muted
        }
    }
    Text {
        property int volume: AudioService.volume
            property bool muted: AudioService.muted
                id: audio

                anchors {
                    verticalCenter: parent.verticalCenter

                }
                text: {
                    if (muted || volume === 0) return "󰝟  " + volume + "%"
                    if (volume < 33) return "󰕿  " + volume + "%"
                    if (volume < 66) return " 󰖀  " + volume + "%"
                    return "󰕾  " + volume + "%"
                }

                color: '#ffffff'
                font.family: "Jost* 600 Semi"
                font.pixelSize: 16
                Component.onCompleted: {
                    parent.width = audio.contentWidth
                }
            }
        }