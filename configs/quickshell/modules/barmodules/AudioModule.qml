import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property int volume: -1
    property bool muted: false

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: {
                if (root.volume < 0 || root.muted) return theme.iconVolMute;
                if (root.volume > 60)  return theme.iconVolHigh;
                if (root.volume > 30)  return theme.iconVolMid;
                if (root.volume > 0)   return theme.iconVolLow;
                return theme.iconVolMute;
            }
            color: root.muted ? theme.textDimmed : theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                if (root.volume < 0) return "--";
                if (root.muted) return "mute";
                return root.volume + "%";
            }
            color: root.muted ? theme.textDimmed : theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Process {
        id: proc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                root.muted = data.indexOf("[MUTED]") !== -1;
                let parts = data.split(" ");
                if (parts.length >= 2) {
                    let frac = parseFloat(parts[1]);
                    if (!isNaN(frac)) root.volume = Math.round(frac * 100);
                }
            }
        }

        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: 100
        onTriggered: proc.running = true
    }
}
