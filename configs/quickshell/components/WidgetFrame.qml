import QtQuick
import ".." as Root

// Universal widget container with frame styling, positioning, and animation
Item {
    id: frame

    property string widgetName
    property bool configVisible: true
    property color accentColor: Root.Theme.widgetTextDimmed
    default property alias content: contentArea.data

    implicitWidth: contentArea.implicitWidth + Root.Theme.widgetPadding * 2
    implicitHeight: contentArea.implicitHeight + Root.Theme.widgetPadding * 2

    // Shadow layer
    Rectangle {
        anchors.fill: bg
        anchors.margins: -2
        anchors.topMargin: 2
        radius: Root.Theme.widgetRadius + 2
        color: Root.Theme.widgetShadowColor
        opacity: 0.4
    }

    // Widget background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Theme.widgetBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Item {
        id: contentArea
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
