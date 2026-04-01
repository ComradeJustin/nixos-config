import QtQuick
import ".." as Root

// Standardized toggle button for ControlCenter quick toggles
Rectangle {
    id: toggle

    property bool isOn: false
    property string iconOn: ""
    property string iconOff: ""
    property color accent: Root.Theme.accentPrimary

    signal toggled()

    width: 40; height: 40
    radius: Root.Theme.radiusSmall
    color: mouse.containsMouse
        ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1)
        : (isOn ? Qt.rgba(accent.r, accent.g, accent.b, 0.15) : "transparent")
    border.width: Root.Theme.borderWidth
    border.color: isOn ? accent : Root.Theme.borderColor

    Text {
        anchors.centerIn: parent
        text: toggle.isOn ? toggle.iconOn : toggle.iconOff
        color: toggle.isOn ? toggle.accent : Root.Theme.textDimmed
        font { family: Root.Theme.fontFamily; pixelSize: 16 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
