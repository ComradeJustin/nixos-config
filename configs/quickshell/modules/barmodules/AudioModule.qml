import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    property var audioService: null
    property int volume: audioService ? audioService.volume : -1
    property bool muted: audioService ? audioService.muted : false

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: volIcon
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (root.volume < 0 || root.muted) return Root.Theme.iconVolMute;
                if (root.volume > 60) return Root.Theme.iconVolHigh;
                if (root.volume > 30) return Root.Theme.iconVolMid;
                if (root.volume > 0) return Root.Theme.iconVolLow;
                return Root.Theme.iconVolMute;
            }
            color: root.muted ? Root.Theme.textDimmed : Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.volume >= 0 ? root.volume + "%" : "--"
            color: root.muted ? Root.Theme.textDimmed : Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: Root.Theme.fontBold }
        }
    }
}
