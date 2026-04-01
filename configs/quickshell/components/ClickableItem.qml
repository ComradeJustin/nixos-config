import QtQuick
import ".." as Root

// Base component for all interactive list items — handles hover/selected state
Rectangle {
    id: item

    property color hoverColor: Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
    property color selectedColor: Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.12)
    property bool selected: false
    property alias hovered: mouseArea.containsMouse
    signal clicked()
    default property alias content: contentItem.data

    color: selected ? selectedColor : (mouseArea.containsMouse ? hoverColor : "transparent")
    radius: Root.Theme.radiusSmall

    Item { id: contentItem; anchors.fill: parent }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }
}
