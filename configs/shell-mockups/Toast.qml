import QtQuick
import Quickshell
import Quickshell.Wayland

// What a notification looks like. The clock pill in the top gap grows
// downward into the message, then shrinks back into the pill.
PanelWindow {
    id: toast

    // The shell root (shell.qml).
    required property var shell

    // 0 = the resting pill, 1 = the full message.
    property real growth: shell.toastShown ? 1 : 0
    readonly property real shown: Math.max(0, Math.min(1, growth))

    Behavior on growth {
        SpringAnimation {
            spring: Theme.panelSpring
            damping: Theme.panelDamping
            epsilon: 0.002
        }
    }

    // Stay mapped while the closing spring is still settling.
    visible: shell.toastShown || growth > 0.02
    anchors.top: true
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 420
    implicitHeight: 100
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        // From the size of the clock pill to the full message.
        width: 130 + 270 * toast.growth
        height: 16 + 62 * toast.growth
        radius: 8 + 4 * toast.shown
        color: Theme.surface
        border.width: 1
        border.color: Theme.stroke
        clip: true

        Column {
            x: 16
            y: 13
            width: parent.width - 32
            spacing: 3
            // The contents arrive in the second half of the growth.
            opacity: Math.max(0, (toast.shown - 0.5) * 2)

            Label {
                text: "vesktop  ·  now"
                caps: true
                mono: true
                color: Theme.textDim
                font.pixelSize: 9
            }

            Label {
                width: parent.width
                text: "Mara"
                weight: 780
                color: Theme.textStrong
                elide: Text.ElideRight
                font.pixelSize: 14
            }

            Label {
                width: parent.width
                text: "are you still coming tonight?"
                color: Theme.text
                elide: Text.ElideRight
                font.pixelSize: 12
            }
        }
    }
}
