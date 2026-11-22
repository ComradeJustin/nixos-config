import QtQuick

// The always-visible status cluster: network, volume and battery.
// Sample values only. Clicking it is how a layout opens the status panel.
Item {
    id: root

    // Stack the icons top to bottom (for a side rail) instead of left to right.
    property bool vertical: false
    property int iconSize: 14
    property int labelSize: 12
    property int spacing: vertical ? 12 : 14
    signal clicked

    implicitWidth: icons.implicitWidth
    implicitHeight: icons.implicitHeight

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        onClicked: root.clicked()
    }

    Grid {
        id: icons

        rows: root.vertical ? 3 : 1
        columns: root.vertical ? 1 : 3
        spacing: root.spacing
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Text {
            text: Icons.wifiHi
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: root.iconSize
        }

        Text {
            text: Icons.volMid
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: root.iconSize
        }

        Grid {
            rows: root.vertical ? 2 : 1
            columns: root.vertical ? 1 : 2
            spacing: root.vertical ? 2 : 5
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Text {
                text: Icons.bat40
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: root.iconSize
            }

            Text {
                text: root.vertical ? "28" : "28%"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: root.labelSize
            }
        }
    }
}
