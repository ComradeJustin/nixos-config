import QtQuick
import ".." as Root

// Label + value row for hover popups
Item {
    id: row

    property string label: ""
    property string value: ""
    property color valueColor: Root.Theme.textPrimary
    property color labelColor: Root.Theme.textDimmed

    width: parent ? parent.width : 0
    height: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    Text {
        id: labelText
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: row.label
        color: row.labelColor
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
    }

    Text {
        id: valueText
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: row.value
        color: row.valueColor
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; bold: true }
    }
}
