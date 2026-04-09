import QtQuick
import QtQuick.Effects
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

    // Widget background with MultiEffect shadow
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

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Root.Theme.widgetShadowColor
            shadowBlur: hoverArea.containsMouse ? 1.0 : 0.7
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
            shadowOpacity: hoverArea.containsMouse ? 0.6 : 0.35
            Behavior on shadowBlur { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
            Behavior on shadowOpacity { NumberAnimation { duration: Root.Theme.anim.moveDuration } }
        }
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
