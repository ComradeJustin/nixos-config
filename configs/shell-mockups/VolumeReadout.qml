import QtQuick
import Quickshell
import Quickshell.Wayland

// What a volume key press looks like: a small panel drops out of the right
// end of the bar with a long bar and the number, then slides back up.
PanelWindow {
    id: readout

    // The shell root (shell.qml).
    required property var shell

    // 0 = tucked into the bar, 1 = fully dropped.
    property real drop: shell.volumeShown ? 1 : 0

    Behavior on drop {
        SpringAnimation {
            spring: Theme.dropSpring
            damping: Theme.dropDamping
            epsilon: 0.002
        }
    }

    // Stay mapped while the closing spring is still settling.
    visible: shell.volumeShown || drop > 0.02
    anchors {
        top: true
        right: true
    }
    margins.right: Theme.cellWidth
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

        y: Math.round(-implicitHeight * (1 - readout.drop))
        columns: 36
        rows: 1
        title: "volume"

        Level {
            level: readout.shell.volume / 100
            cells: panel.contentColumns - 4
        }

        Label {
            anchors.right: parent.right
            text: readout.shell.volume
            color: Theme.ink
        }
    }
}
