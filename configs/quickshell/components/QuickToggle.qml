import QtQuick
import ".." as Root

// Standardized toggle button for ControlCenter quick toggles
// Features: animated state transitions, scale feedback on press, glow on active
Rectangle {
    id: toggle

    property bool isOn: false
    property string iconOn: ""
    property string iconOff: ""
    property color accent: Root.Theme.accentPrimary
    property string label: ""

    signal toggled()
    signal secondaryAction()

    width: 40; height: 40
    radius: Root.Theme.radiusSmall
    color: mouse.containsMouse
        ? Root.Theme.layer1Hover
        : (isOn ? Qt.rgba(accent.r, accent.g, accent.b, 0.15) : "transparent")
    border.width: Root.Theme.borderWidth
    border.color: isOn ? accent : Root.Theme.borderColor

    scale: mouse.pressed ? 0.92 : 1.0

    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    Text {
        anchors.centerIn: parent
        text: toggle.isOn ? toggle.iconOn : toggle.iconOff
        color: toggle.isOn ? toggle.accent : Root.Theme.textDimmed
        font { family: Root.Theme.fontFamily; pixelSize: 16 }

        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

        // Subtle bounce on state change
        scale: 1.0
        SequentialAnimation on scale {
            id: iconBounce
            running: false
            NumberAnimation { to: 1.2; duration: 100; easing.type: Easing.OutCubic }
            NumberAnimation { to: 1.0; duration: 150; easing.type: Easing.OutBack }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouseEvent) {
            if (mouseEvent.button === Qt.RightButton) {
                toggle.secondaryAction();
            } else {
                iconBounce.restart();
                toggle.toggled();
            }
        }
    }
}
