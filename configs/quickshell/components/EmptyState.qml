import QtQuick
import ".." as Root

// Empty-state placeholder for lists with no items: an optional icon glyph above
// a message, with an optional secondary hint line. `message`/`preferredHeight`
// are kept for backwards-compatibility with existing call sites.
Item {
    id: root

    property string icon: ""        // Nerd Font glyph (optional)
    property string message: "NO ITEMS"
    property string hint: ""        // optional secondary line
    property int preferredHeight: 50

    width: parent ? parent.width : 100
    height: Math.max(preferredHeight, col.implicitHeight)

    Column {
        id: col
        anchors.centerIn: parent
        spacing: Root.Theme.spacingXS

        Text {
            visible: root.icon !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: Root.Theme.textDimmed
            opacity: 0.5
            font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize5XL }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.message
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL }
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            visible: root.hint !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hint
            color: Root.Theme.textDimmed
            opacity: 0.6
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
