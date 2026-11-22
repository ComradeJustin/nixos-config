import QtQuick
import Quickshell
import Quickshell.Wayland

// What a notification looks like: a panel titled with the app is printed
// under the clock, a row at a time, then erased.
PanelWindow {
    id: toast

    // The shell root (shell.qml).
    required property var shell

    // 0 = nothing printed, 1 = the whole panel.
    property real reveal: shell.toastShown ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: (panel.rows + 1) * Theme.rowMs
        }
    }

    // Stay mapped until the last row has been erased.
    visible: shell.toastShown || reveal > 0
    anchors.top: true
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

        columns: 52
        rows: 2
        title: "Vesktop"
        footer: "now"
        reveal: toast.reveal

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
