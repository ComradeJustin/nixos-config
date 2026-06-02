import QtQuick
import ".." as Root

// Consistent Control-Center card header: an accent icon + title on the left,
// with an optional trailing action/status slot on the right. Children placed
// inside a CCCardHeader land in that trailing slot. Title uses the UI font
// (Hanken) bold per the type scale; the icon uses the card's domain accent.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property color accent: Root.Theme.textPrimary
    default property alias trailing: trailingSlot.data

    implicitHeight: Math.max(headerRow.implicitHeight, trailingSlot.childrenRect.height)

    Row {
        id: headerRow
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: Root.Theme.spacingS

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon.length > 0
            text: root.icon
            color: root.accent
            font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSizeXL }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Root.Theme.textPrimary
            // Display serif (Fraunces) for card titles — "serif accents" direction.
            font { family: Root.Theme.fontDisplay; pixelSize: Root.Theme.fontSize2XL; weight: Font.Medium }
        }
    }

    Item {
        id: trailingSlot
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: childrenRect.height
    }
}
