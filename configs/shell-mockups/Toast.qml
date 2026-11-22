import QtQuick
import Quickshell
import Quickshell.Wayland

// What a notification looks like: a panel titled with the app drops out of
// the bar under the clock, then slides back up.
PanelWindow {
    id: toast

    // The shell root (shell.qml).
    required property var shell

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
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    // The window clips the panel, so it appears to slide out from under the bar.
    Box {
        id: panel

        y: Math.round(-implicitHeight * (1 - toast.drop))
        columns: 52
        rows: 2
        title: "Vesktop"
        footer: "now"

        Label {
            text: "Mara"
            color: Theme.ink
        }

        Label {
            y: Theme.cellHeight
            text: "are you still coming tonight?"
        }
    }
}
