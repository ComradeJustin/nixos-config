import QtQuick
import ".." as Root

// Lightweight popup content wrapper for use with the bar's shared popup window.
// Usage in modules:
//   Component.onCompleted: barPopup registered via BarItem.popupItem
//   BarItem handles show/hide via popupItem.show()/hide()
//
// This is a content-only container. The actual popup window is BarPopup.qml in modules/.
Item {
    id: popup

    property int popupWidth: 220
    default property alias content: contentCol.data

    width: popupWidth
    height: contentCol.implicitHeight + 20

    Rectangle {
        anchors.fill: parent
        radius: Root.Theme.radiusMedium
        color: Root.Theme.barBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Column {
        id: contentCol
        anchors {
            left: parent.left; right: parent.right
            top: parent.top
            margins: 10
        }
        spacing: 6
    }
}
