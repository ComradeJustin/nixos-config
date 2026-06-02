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

    // No hover-scale: scaling a fixed-size glass surface's content softens the
    // text and desyncs it from the (unscaled) compositor blur + rounded
    // corners. Hover feedback is the border highlight below instead.

    // Widget background with MultiEffect shadow
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Config.widgets.glass ? Root.Theme.widgetBackground : Root.Theme.widgetBackgroundSolid
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

        // Soft shadow keeps content legible over the blurred-wallpaper glass,
        // no matter how busy the wallpaper behind it is.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
