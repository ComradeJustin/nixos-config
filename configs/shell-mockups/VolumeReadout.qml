import QtQuick
import Quickshell
import Quickshell.Wayland

// What a volume key press looks like: a small panel is typed in at the right
// end of the bar with a long bar and the number, then erased.
PanelWindow {
    id: readout

    // The shell root (shell.qml).
    required property var shell

    // 0 = nothing typed, 1 = the whole panel.
    property real typed: shell.volumeShown ? 1 : 0

    Behavior on typed {
        NumberAnimation {
            duration: Theme.typeMs
        }
    }

    // Stay mapped until the last character has been erased.
    visible: shell.volumeShown || typed > 0
    anchors {
        top: true
        right: true
    }
    margins.right: Theme.cellWidth
    // Directly under the bar, or against the top of the screen when a
    // fullscreen window has covered the bar.
    margins.top: shell.fullscreen ? 0 : Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    Box {
        id: panel

        columns: 36
        rows: 1
        title: "volume"
        typed: readout.typed

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
