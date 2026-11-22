import QtQuick
import Quickshell
import Quickshell.Wayland

// What a volume key press looks like: a small panel is wiped in at the right
// end of the bar with a long bar and the number, then wiped away. The number
// flashes each time it changes.
PanelWindow {
    id: readout

    // The shell root (shell.qml).
    required property var shell

    // 0 = nothing showing, 1 = the whole panel.
    property real shown: shell.volumeShown ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // Stay mapped until the panel has been wiped away.
    visible: shell.volumeShown || shown > 0
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
        shown: readout.shown

        Level {
            level: readout.shell.volume / 100
            cells: panel.contentColumns - 4
        }

        Value {
            anchors.right: parent.right
            text: readout.shell.volume
        }
    }
}
