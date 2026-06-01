import QtQuick
import ".." as Root

// Standardised quick-toggle (ControlCenter). Built on ClickableItem.
// Animated state, press-scale feedback, accent border + tint when on.
ClickableItem {
    id: toggle

    property bool isOn: false
    property string iconOn: ""
    property string iconOff: ""
    property color accent: Root.Theme.accentPrimary
    property string label: ""

    signal toggled()
    signal secondaryAction()

    width: 40
    height: 40
    pressScale: true
    pressScaleAmount: 0.92

    // "On" uses the selected surface tint; hover composites over it.
    selected: isOn
    selectedColor: Qt.rgba(accent.r, accent.g, accent.b, 0.15)

    border.width: Root.Theme.borderWidth
    border.color: isOn ? accent : Root.Theme.borderColor
    Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

    onClicked: {
        iconBounce.restart();
        toggle.toggled();
    }
    onRightClicked: toggle.secondaryAction()

    Text {
        anchors.centerIn: parent
        text: toggle.isOn ? toggle.iconOn : toggle.iconOff
        color: toggle.isOn ? toggle.accent : Root.Theme.textDimmed
        font: Root.Theme.fontIcon

        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

        // Subtle bounce on state change
        scale: 1.0
        SequentialAnimation on scale {
            id: iconBounce
            running: false
            NumberAnimation { to: 1.2; duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic }
            NumberAnimation { to: 1.0; duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutBack }
        }
    }
}
