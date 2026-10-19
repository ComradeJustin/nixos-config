import QtQuick
import ".." as Root

// Settings pane is a placeholder until we design the actual pages.
Item {
    id: root
    implicitHeight: inner.implicitHeight + 32

    Column {
        id: inner
        width: parent.width
        topPadding: 28
        bottomPadding: 28
        spacing: 8

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing here yet"
            color: Root.Theme.text
            font { family: Root.Theme.fontUi; pixelSize: 16; weight: Font.DemiBold }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Settings will live in this pane."
            color: Root.Theme.textDim
            font { family: Root.Theme.fontUi; pixelSize: 13 }
        }
    }
}
