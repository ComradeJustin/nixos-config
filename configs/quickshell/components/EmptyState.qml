import QtQuick
import ".." as Root

// Empty state placeholder for lists with no items
Text {
    property string message: "NO ITEMS"
    property int preferredHeight: 50

    text: message
    color: Root.Theme.textDimmed
    font { family: Root.Theme.fontFamily; pixelSize: 13 }
    width: parent ? parent.width : 100
    height: preferredHeight
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
