import QtQuick
import Qt5Compat.GraphicalEffects
import ".." as Root

// Universal widget container with frame styling, hover effects, and animation
Item {
    id: frame

    property string widgetName
    property bool configVisible: true
    property color accentColor: Root.Theme.widgetTextDimmed
    default property alias content: contentArea.data

    implicitWidth: contentArea.implicitWidth + Root.Theme.widgetPadding * 2
    implicitHeight: contentArea.implicitHeight + Root.Theme.widgetPadding * 2

    scale: hoverArea.containsMouse ? 1.02 : 1.0
    Behavior on scale { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }

    // Shadow layer — grows on hover with blur
    Rectangle {
        id: shadow
        anchors.fill: bg
        anchors.margins: -2
        anchors.topMargin: 2
        radius: Root.Theme.widgetRadius + 2
        color: "transparent"
        visible: false
    }

    DropShadow {
        anchors.fill: shadow
        source: shadow
        horizontalOffset: 0
        verticalOffset: 2
        radius: hoverArea.containsMouse ? Root.Theme.widgetShadowRadius + 4 : Root.Theme.widgetShadowRadius
        samples: radius * 2 + 1
        color: Root.Theme.widgetShadowColor
        opacity: hoverArea.containsMouse ? 0.6 : 0.35
        Behavior on radius { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.moveDuration } }
    }

    // Widget background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Theme.widgetBackground
        border.width: Root.Theme.borderWidth
        border.color: hoverArea.containsMouse
            ? Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.5)
            : Root.Theme.borderColor
        Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.moveDuration } }
    }

    Item {
        id: contentArea
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
