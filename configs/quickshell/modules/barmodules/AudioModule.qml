import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property var audioService: null
    property int volume: audioService ? audioService.volume : -1
    property bool muted: audioService ? audioService.muted : false

    Row {
        id: row; spacing: 4; anchors.verticalCenter: parent.verticalCenter

        Text {
            text: {
                if (root.volume < 0 || root.muted) return theme.iconVolMute;
                if (root.volume > 60) return theme.iconVolHigh;
                if (root.volume > 30) return theme.iconVolMid;
                if (root.volume > 0) return theme.iconVolLow;
                return theme.iconVolMute;
            }
            color: root.muted ? theme.textDimmed : theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                if (root.volume < 0) return "VOL --";
                if (root.muted) return "MUTE";
                return "VOL " + root.volume + "%";
            }
            color: root.muted ? theme.textDimmed : theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
