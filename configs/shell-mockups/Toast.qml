import QtQuick
import Quickshell
import Quickshell.Wayland

// What a notification looks like: a slab drops out of the bar under the
// clock, then slides back up.
PanelWindow {
    id: toast

    // The shell root (shell.qml).
    required property var shell

    readonly property int slabWidth: 440
    readonly property int slabHeight: 76

    // 0 = tucked into the bar, 1 = fully dropped.
    property real drop: shell.toastShown ? 1 : 0

    Behavior on drop {
        SpringAnimation {
            spring: Theme.dropSpring
            damping: Theme.dropDamping
            epsilon: 0.002
        }
    }

    // Stay mapped while the closing spring is still settling.
    visible: shell.toastShown || drop > 0.02
    anchors.top: true
    // Zone 0 in normal mode places this directly under the bar.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: slabWidth
    implicitHeight: slabHeight
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    // The window clips the slab, so it appears to slide out from under the bar.
    Rectangle {
        y: -toast.slabHeight * (1 - toast.drop)
        width: toast.slabWidth
        height: toast.slabHeight
        color: Theme.slab
        border.width: 1
        border.color: Theme.rule

        // Halftone strip down the left edge, marking it as a message.
        Dither {
            x: 1
            y: 1
            width: 10
            height: parent.height - 2
            color: Theme.accent
        }

        Label {
            x: 26
            y: 12
            text: "vesktop  ·  now"
            caps: true
            color: Theme.inkDim
            font.pixelSize: 8
        }

        Label {
            x: 26
            y: 26
            width: parent.width - 42
            text: "Mara"
            mono: false
            weight: 780
            color: Theme.ink
            elide: Text.ElideRight
            font.pixelSize: 14
        }

        Label {
            x: 26
            y: 47
            width: parent.width - 42
            text: "are you still coming tonight?"
            mono: false
            color: Theme.inkSoft
            elide: Text.ElideRight
            font.pixelSize: 12
        }
    }
}
