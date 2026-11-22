import QtQuick
import Quickshell
import Quickshell.Wayland

// What a volume key press looks like: a small panel is printed under the
// right end of the bar with a long bar and the number, then erased.
PanelWindow {
    id: readout

    // The shell root (shell.qml).
    required property var shell

    // 0 = nothing printed, 1 = the whole panel.
    property real reveal: shell.volumeShown ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: panel.lineCount * Theme.lineMs
        }
    }

    // Stay mapped until the last row has been erased.
    visible: shell.volumeShown || reveal > 0
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

    Box {
        id: panel

        columns: 36
        rows: 1
        title: "volume"
        reveal: readout.reveal

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
